import Combine
import SwiftUI

class ScopedSubject<ObjectType, Value>: ObservableObject, DynamicProperty
  where
  ObjectType: ObservableObject,
  ObjectType.ObjectWillChangePublisher == ObservableObjectPublisher
{
  @UnobservedEnvironmentObject var root: ObjectType
  let keyPath: KeyPath<ObjectType, Value>
  var isSending = false

  var cancellable: AnyCancellable?
  var subscriptionId: SubscriptionId?

  var currentValue: Value?

  var subscribe: (ObjectType, ScopedSubject) -> AnyCancellable?
  var getSubscriptionId: (ObjectType) -> SubscriptionId?

  var value: Value {
    get { self.currentValue ?? self.root[keyPath: self.keyPath] }
    set { self.send(newValue) }
  }

  func send(_ value: Value) {
    guard let keyPath = self.keyPath as? ReferenceWritableKeyPath<ObjectType, Value> else { return }
    self.isSending = true
    self.objectWillChange.send()
    self.currentValue = value
    self.root[keyPath: keyPath] = value
    self.isSending = false
  }

  func subscribe(to root: ObjectType) -> AnyCancellable? {
    self.subscribe(root, self)
  }

  func updateSubscription(to root: ObjectType) {
    let newId = self.getSubscriptionId(root)
    guard newId != self.subscriptionId else { return }
    self.subscriptionId = newId
    self.cancellable = nil
    self.cancellable = self.subscribe(to: root)
    if !self.isSending, self.currentValue != nil {
      self.objectWillChange.send()
    }
    self.currentValue = root[keyPath: self.keyPath]
  }

  func update() {
    self.updateSubscription(to: self.root)
  }

  init(_ keyPath: KeyPath<ObjectType, Value>) {
    self.keyPath = keyPath
    self.subscribe = { $0.subscribe($1, scope: keyPath) }
    self.getSubscriptionId = { .value(root: ObjectIdentifier($0)) }
  }

  init(_ keyPath: ReferenceWritableKeyPath<ObjectType, Value>) {
    self.keyPath = keyPath
    self.subscribe = { $0.subscribe($1, scope: keyPath) }
    self.getSubscriptionId = { .value(root: ObjectIdentifier($0)) }
  }

  init(_ keyPath: KeyPath<ObjectType, Value>)
    where
    Value: ObservableObject,
    Value.ObjectWillChangePublisher == ObservableObjectPublisher
  {
    self.keyPath = keyPath
    self.subscribe = { $0.subscribe($1, scope: keyPath) }
    self.getSubscriptionId = { .observable(object: ObjectIdentifier($0[keyPath: keyPath]), root: ObjectIdentifier($0)) }
  }

  init(_ keyPath: ReferenceWritableKeyPath<ObjectType, Value>)
    where
    Value: ObservableObject, Value.ObjectWillChangePublisher == ObservableObjectPublisher
  {
    self.keyPath = keyPath
    self.subscribe = { $0.subscribe($1, scope: keyPath) }
    self.getSubscriptionId = { .observable(object: ObjectIdentifier($0[keyPath: keyPath]), root: ObjectIdentifier($0)) }
  }

  enum SubscriptionId: Equatable {
    case value(root: ObjectIdentifier?)
    case observable(object: ObjectIdentifier?, root: ObjectIdentifier?)

    static func == (lhs: SubscriptionId, rhs: SubscriptionId) -> Bool {
      switch (lhs, rhs) {
      case let (.value(lhsRootId), .value(rhsRootId)):
        return lhsRootId == rhsRootId
      case let (.observable(lhsObjectId, lhsRootId), .observable(rhsObjectId, rhsRootId)):
        return lhsObjectId == rhsObjectId && lhsRootId == rhsRootId
      default: return false
      }
    }
  }
}

extension ObservableObject {
  func subscribe<Value>(
    _ subject: ScopedSubject<Self, Value>,
    scope toScopedValue: KeyPath<Self, Value>
  ) -> AnyCancellable {
    self.objectWillChange
      .compactMap { [weak self, weak subject] _ -> Value? in
        guard
          let self = self,
          let subject = subject,
          !subject.isSending else { return nil }
        return self[keyPath: toScopedValue]
      }
      .receive(on: DispatchQueue.main)
      .sink { [weak self, weak subject] oldValue in
        guard
          let self = self,
          let subject = subject
        else { return }
        let newValue = self[keyPath: toScopedValue]
        guard !areEqual(oldValue, newValue) else { return }
        subject.objectWillChange.send()
        subject.currentValue = newValue
      }
  }

  func subscribe<Value>(
    _ subject: ScopedSubject<Self, Value>,
    scope toScopedValue: KeyPath<Self, Value>
  ) -> AnyCancellable
    where
    Value: ObservableObject
  {
    let childCancellable = self[keyPath: toScopedValue].objectWillChange.sink { [weak subject] _ in
      subject?.objectWillChange.send()
    }

    let parentCancellable = self.objectWillChange
      .filter { [weak subject] _ in subject.map { !$0.isSending } ?? false }
      .receive(on: DispatchQueue.main)
      .sink { [weak subject] _ in
        guard let subject = subject, !subject.isSending else { return }
        subject.updateSubscription(to: subject.root)
      }

    return AnyCancellable { _ = (childCancellable, parentCancellable) }
  }
}
