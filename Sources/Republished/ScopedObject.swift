import Combine
import SwiftUI

class ScopedObject<ObjectType, Value>: ObservableObject
  where
  ObjectType: ObservableObject

{
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

