import Combine
import SwiftUI

class ScopedSubject<ObjectType, Value>: ObservableObject, DynamicProperty
  where
  ObjectType: ObservableObject,
  ObjectType.ObjectWillChangePublisher == ObservableObjectPublisher
{
  @UnobservedEnvironmentObject var root: ObjectType

  var cancellable: AnyCancellable?

  enum SubscriptionId: Equatable {
    case value(root: ObjectIdentifier?)
    case observable(object: ObjectIdentifier?, root: ObjectIdentifier?)
  }

  var subscriptionId: SubscriptionId?

  var isSending = false

  let keyPath: KeyPath<ObjectType, Value>

  var subscribe: (ObjectType, ScopedSubject) -> AnyCancellable?

  var getSubscriptionId: (ObjectType) -> SubscriptionId?

  var currentValue: Value?

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

    self.updateSubscription(to: self.root)

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

  init(_ keyPath: KeyPath<ObjectType, Value>) where ObjectType.ObjectWillChangePublisher == ObservableObjectPublisher {
    self.keyPath = keyPath

    self.subscribe = { $0.subscribe($1, scope: keyPath) }

    self.getSubscriptionId = { root in
      .value(root: ObjectIdentifier(root))
    }
  }

  convenience init(_ keyPath: ReferenceWritableKeyPath<ObjectType, Value>)
    where ObjectType.ObjectWillChangePublisher == ObservableObjectPublisher
  {
    self.init(keyPath as KeyPath<ObjectType, Value>)
  }

  init(_ keyPath: KeyPath<ObjectType, Value>)
    where ObjectType.ObjectWillChangePublisher == ObservableObjectPublisher,
    Value: ObservableObject, Value.ObjectWillChangePublisher == ObservableObjectPublisher
  {
    self.keyPath = keyPath
    self.subscribe = { $0.subscribe($1, scope: keyPath) }

    self.getSubscriptionId = { root in
      .observable(object: ObjectIdentifier(root[keyPath: keyPath]), root: ObjectIdentifier(root))
    }
  }

  convenience init(_ keyPath: ReferenceWritableKeyPath<ObjectType, Value>)
    where ObjectType.ObjectWillChangePublisher == ObservableObjectPublisher,
    Value: ObservableObject, Value.ObjectWillChangePublisher == ObservableObjectPublisher
  {
    self.init(keyPath as KeyPath<ObjectType, Value>)
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
      .sink { [weak subject, weak self] _ in
        guard let self = self, let subject = subject, !subject.isSending else { return }
        subject.updateSubscription(to: self)
      }

    return AnyCancellable { _ = (childCancellable, parentCancellable) }
  }
}
