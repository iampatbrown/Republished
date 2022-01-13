import Combine
import SwiftUI

class ScopedObject<ObjectType, Value>: ObservableObject where ObjectType: ObservableObject {
  let keyPath: KeyPath<ObjectType, Value>
  var cancellable: AnyCancellable?
//  var changePublisherId: ObjectIdentifier?
  var isSending = false

  var cancellable2: AnyCancellable?

  weak var changePublisher: AnyObject?

  var currentValue: Value?

  weak var object: ObjectType? {
    didSet {
      guard let object = self.object else { return }

      self.currentValue = object[keyPath: self.keyPath]
//      if let changePublisher = ObservableObjectPublisher.extract(from: object[keyPath: self.keyPath]) {
//        self.cancellable = changePublisher.sink { [weak self] in self?.objectWillChange.send() }
//      }
      guard oldValue !== self.object else { return }
      if let changePublisher = ObservableObjectPublisher.extract(from: object[keyPath: self.keyPath]) {
        if self.changePublisher !== changePublisher {}

//        self.cancellable = changePublisher.sink { [weak self] in self?.objectWillChange.send() }
        self.cancellable2 = changePublisher.sink { [weak self] in self?.objectWillChange.send() }

        self.cancellable = object.objectWillChange.sink { [weak self, weak object] _ in
          guard let initialValue = self?.value as AnyObject? else { return }

          guard
            let self = self,
            let newValue = object?[keyPath: self.keyPath] as AnyObject?,
            initialValue !== newValue else { return }

          if let changePublisher = ObservableObjectPublisher.extract(from: newValue) {
            self.cancellable2 = nil
            self.cancellable2 = changePublisher
              .sink { [weak self] in self?.objectWillChange.send() }
          }
          self.objectWillChange.send()
          self.currentValue = newValue as! Value?
        }

      } else {
        self.cancellable = object.objectWillChange.sink { [weak self, weak object] _ in
          guard let initialValue = self?.value else { return }
          DispatchQueue.main.async { [weak self, weak object] in
            guard
              let self = self,
              let newValue = object?[keyPath: self.keyPath],
              !areEqual(initialValue, newValue) else { return }
            self.currentValue = newValue
          }
        }
      }
    }
  }

  init(_ keyPath: KeyPath<ObjectType, Value>) {
    self.keyPath = keyPath
  }

  init(_ keyPath: KeyPath<ObjectType, Value>) where Value: ObservableObject {
    self.keyPath = keyPath
  }

  init(_ keyPath: ReferenceWritableKeyPath<ObjectType, Value>) {
    self.keyPath = keyPath
  }

  init(_ keyPath: ReferenceWritableKeyPath<ObjectType, Value>) where Value: ObservableObject {
    self.keyPath = keyPath
  }

  var value: Value? {
    get { self.currentValue ?? self.object?[keyPath: self.keyPath] }
    set { newValue.map(self.send) }
  }

  func send(_ value: Value) {
    self.objectWillChange.send()
    self.currentValue = value
    if let keyPath = self.keyPath as? ReferenceWritableKeyPath<ObjectType, Value> {
      self.object?[keyPath: keyPath] = value
    }
  }
}

class ScopedSubject<ObjectType, Value>: ObservableObject, DynamicProperty where ObjectType: ObservableObject {
  @UnobservedEnvironmentObject var object: ObjectType

  var cancellable: AnyCancellable?
  weak var changePublisher: AnyObject?

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
    self.objectWillChange.send()
    self.currentValue = value
    if let keyPath = self.keyPath as? ReferenceWritableKeyPath<ObjectType, Value> {
      self.isSending = true
      self.object[keyPath: keyPath] = value
      self.updateSubscription(self.object, self)
      self.isSending = false
    }
  }

  func update() {
    self.updateSubscription(self.object, self)
  }

  init(_ keyPath: KeyPath<ObjectType, Value>) where ObjectType.ObjectWillChangePublisher == ObservableObjectPublisher {
    self.keyPath = keyPath

    self.subscribe = { object, subject in
      object.objectWillChange.sink { [weak object, weak subject] in
        guard
          let object = object,
          let subject = subject else { return }
        let oldValue = object[keyPath: keyPath]
        DispatchQueue.main.async { [weak object, weak subject] in
          guard
            let subject = subject,
            let newValue = object?[keyPath: keyPath],
            !areEqual(oldValue, newValue)
          else { return }
          subject.objectWillChange.send()
          subject.currentValue = newValue
        }
      }
    }

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
//      object, subject in
//      let childCancellable = object[keyPath: keyPath]
//        .objectWillChange.sink { [weak subject] in
//          subject?.objectWillChange.send()
//        }
//
//      let parentCancellable = object.objectWillChange.sink { [weak subject] in
//        guard let subject = subject, !subject.isSending else { return }
//        DispatchQueue.main.async { [weak subject] in
//          guard
//            let subject = subject else { return }
//          subject.updateSubscription(subject.object, subject)
//        }
//      }
//
//      return AnyCancellable { _ = (childCancellable, parentCancellable) }
//    }

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

  func updateSubscription(to object: ObjectType)
    where
    ObjectType.ObjectWillChangePublisher == ObservableObjectPublisher,
    Value: ObservableObject,
    Value.ObjectWillChangePublisher == ObservableObjectPublisher
  {
    let changePublisher = object[keyPath: self.keyPath].objectWillChange
    guard self.changePublisher !== changePublisher else { return }
    self.changePublisher = changePublisher
    self.cancellable = nil
//      self.cancellable = self.sub
  }

  func subscribe(to object: ObjectType)
    where
    ObjectType.ObjectWillChangePublisher == ObservableObjectPublisher,
    Value: ObservableObject,
    Value.ObjectWillChangePublisher == ObservableObjectPublisher
  {
    self.cancellable = nil
  }
}

extension ObservableObject {
  func subscribe<Value>(
    _ subject: ScopedSubject<Self, Value>,
    scope toScopedValue: KeyPath<Self, Value>
  ) -> AnyCancellable {
    self.objectWillChange.sink { [weak self, weak subject] _ in
      guard
        let self = self,
        let subject = subject else { return }
      let oldValue = self[keyPath: toScopedValue]
      DispatchQueue.main.async { [weak self, weak subject] in
        guard
          let subject = subject,
          let newValue = self?[keyPath: toScopedValue],
          !areEqual(oldValue, newValue)
        else { return }
        subject.objectWillChange.send()
        subject.currentValue = newValue
      }
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

    let parentCancellable = self.objectWillChange.sink { [weak subject] _ in
      guard let subject = subject, !subject.isSending else { return }
      DispatchQueue.main.async { [weak subject] in
        guard let subject = subject else { return }
        subject.updateSubscription(subject.object, subject)
      }
    }

    return AnyCancellable { _ = (childCancellable, parentCancellable) }
  }
}
