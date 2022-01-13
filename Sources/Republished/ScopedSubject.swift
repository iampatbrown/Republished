import Combine
import SwiftUI

class ScopedSubject<ObjectType, Value>: ObservableObject, DynamicProperty
  where
  ObjectType: ObservableObject,
  ObjectType.ObjectWillChangePublisher == ObservableObjectPublisher
{
  @UnobservedEnvironmentObject var object: ObjectType

  var cancellable: AnyCancellable?

  weak var rootChangePublisher: ObservableObjectPublisher?
  weak var changePublisher: ObservableObjectPublisher?

  var isSending = false

  let keyPath: KeyPath<ObjectType, Value>

  var subscribe: (ObjectType, ScopedSubject) -> AnyCancellable?

  var updateSubscription: (ObjectType, ScopedSubject) -> Void

  var currentValue: Value?

  var value: Value {
    get { self.currentValue ?? self.object[keyPath: self.keyPath] }
    set { self.send(newValue) }
  }

  func send(_ value: Value) {
    guard let keyPath = self.keyPath as? ReferenceWritableKeyPath<ObjectType, Value> else { return }
    self.isSending = true
    self.objectWillChange.send()
    self.currentValue = value
    self.object[keyPath: keyPath] = value

    self.updateSubscription(self.object, self)
    self.isSending = false
  }

  func update() {
    self.updateSubscription(self.object, self)
  }

  init(_ keyPath: KeyPath<ObjectType, Value>) where ObjectType.ObjectWillChangePublisher == ObservableObjectPublisher {
    self.keyPath = keyPath

    self.subscribe = { $0.subscribe($1, scope: keyPath) }

    self.updateSubscription = { object, subject in
      guard object.objectWillChange !== subject.changePublisher else { return }
      subject.changePublisher = object.objectWillChange
      subject.cancellable = nil
      subject.cancellable = subject.subscribe(object, subject)
      subject.objectWillChange.send()
      subject.currentValue = object[keyPath: keyPath]
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

    self.updateSubscription = { object, subject in
      guard object[keyPath: keyPath].objectWillChange !== subject.changePublisher else { return }
      subject.changePublisher = object[keyPath: keyPath].objectWillChange
      subject.cancellable = nil
      subject.cancellable = subject.subscribe(object, subject)
      if !subject.isSending {
        subject.objectWillChange.send()
      }
      subject.currentValue = object[keyPath: keyPath]
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
//  func subscribe<Value>(
//    _ subject: ScopedSubject<Self, Value>,
//    scope toScopedValue: KeyPath<Self, Value>
//  ) -> AnyCancellable {
//    self.objectWillChange
//      .print("objectWillChange.scope")
//      .sink { [weak self, weak subject] _ in
//        let oldValue = self?[keyPath: toScopedValue]
//        Swift.print("oldValue = \(oldValue as Any)")
//        Swift.print("isSending = \(subject?.isSending as Any)")
//        guard
//          let self = self,
//          let subject = subject,
//          let oldValue = oldValue,
//          !subject.isSending else { return }
//
//        DispatchQueue.main.async { [weak self, weak subject] in
//          guard
//            let subject = subject,
//            let newValue = self?[keyPath: toScopedValue],
//            !areEqual(oldValue, newValue) else { return }
//          Swift.print("newValue = \(newValue)")
//          subject.objectWillChange.send()
//          subject.currentValue = newValue
//        }
//      }
//  }

  func subscribe<Value>(
    _ subject: ScopedSubject<Self, Value>,
    scope toScopedValue: KeyPath<Self, Value>
  ) -> AnyCancellable {
    self.objectWillChange
      .filter { [weak subject] _ in subject.map { !$0.isSending } ?? false }
      .map { [weak self] _ in self?[keyPath: toScopedValue] }
      .receive(on: DispatchQueue.main)
      .sink { [weak self, weak subject] oldValue in
        guard
          let self = self,
          let subject = subject,
          let oldValue = oldValue
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

        subject.updateSubscription(subject.object, subject)
      }

    return AnyCancellable { _ = (childCancellable, parentCancellable) }
  }
}
