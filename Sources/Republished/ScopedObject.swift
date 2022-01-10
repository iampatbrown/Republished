import Combine
import SwiftUI

class ScopedObject<ObjectType, Value>: ObservableObject where ObjectType: ObservableObject {
  let keyPath: KeyPath<ObjectType, Value>
  var cancellable: AnyCancellable?
//  var changePublisherId: ObjectIdentifier?
  var isSending = false

  @Published var currentValue: Value?

  weak var object: ObjectType? {
    didSet {
      guard let object = self.object else { return }
//      if let changePublisher = ObservableObjectPublisher.extract(from: object[keyPath: self.keyPath]) {
//        self.cancellable = changePublisher.sink { [weak self] in self?.objectWillChange.send() }
//      }
      guard oldValue !== self.object else { return }
      if let changePublisher = ObservableObjectPublisher.extract(from: object[keyPath: self.keyPath]) {
        self.cancellable = changePublisher.sink { [weak self] in self?.objectWillChange.send() }
      } else {
        self.cancellable = object.objectWillChange.sink { [weak self, weak object] _ in
          guard let initialValue = self?.value else { return }
          DispatchQueue.main.async { [weak self, weak object] in
            guard
              let self = self,
              let newValue = object?[keyPath: self.keyPath],
              !isEqual(initialValue, newValue) else { return }
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
//    self.isSending = true
    self.currentValue = value
    if let keyPath = self.keyPath as? ReferenceWritableKeyPath<ObjectType, Value> {
      self.object?[keyPath: keyPath] = value
    }
//    self.isSending = false
  }
}

class ScopedObject2<ObjectType, Value>: ObservableObject where ObjectType: ObservableObject {
  weak var root: ObjectType?
  let keyPath: ReferenceWritableKeyPath<ObjectType, Value>
  var cancellable: AnyCancellable?
  var isSending = false

  @Published var currentValue: Value?

  init(_ keyPath: ReferenceWritableKeyPath<ObjectType, Value>) {
    self.keyPath = keyPath
  }

  var value: Value? {
    get { self.currentValue ?? self.root?[keyPath: self.keyPath] }
    set { newValue.map(self.send) }
  }

  func send(_ value: Value) {
    self.isSending = true
    self.currentValue = value
    self.root?[keyPath: self.keyPath] = value
    self.isSending = false
  }

  func update(root: ObjectType) {
    guard self.root.map({ $0 !== root }) ?? true else { return }
    self.root = root
    if let changePublisher = ObservableObjectPublisher.extract(from: root[keyPath: self.keyPath]) {
      self.cancellable = changePublisher.sink { [weak self] in self?.objectWillChange.send() }
    } else {
      self.cancellable = root.objectWillChange.sink { [weak self, weak root] _ in
        guard let initialValue = self?.value else { return }
        DispatchQueue.main.async { [weak self, weak root] in
          guard
            let self = self,
            !self.isSending,
            let newValue = root?[keyPath: self.keyPath],
            !isEqual(initialValue, newValue) else { return }
          self.currentValue = newValue
        }
      }
    }
  }
}
