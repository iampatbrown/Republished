import Combine
import SwiftUI

class ScopedObject<ObjectType, Value>: ObservableObject
  where ObjectType: ObservableObject, ObjectType.ObjectWillChangePublisher == ObservableObjectPublisher
{
  let keyPath: KeyPath<ObjectType, Value>
  var currentValue: Value?
  var pendingEvents: [RootEvent] = []
  var cancellable: AnyCancellable?
  let isDuplicate: (Value, Value) -> Bool

  weak var root: ObjectType? {
    didSet {
      guard oldValue !== root, let root = root else { return }
      self.synchronize(with: root)
    }
  }

  var value: Value {
    guard let currentValue = self.currentValue else { fatalError() }
    return currentValue
  }

  init(_ keyPath: KeyPath<ObjectType, Value>, isDuplicate: @escaping (Value, Value) -> Bool) {
    self.keyPath = keyPath
    self.isDuplicate = isDuplicate
  }

  init(_ keyPath: KeyPath<ObjectType, Value>) where Value: Equatable {
    self.keyPath = keyPath
    self.isDuplicate = { $0 == $1 }
  }

  func apply(_ event: RootEvent) {
    guard
      let oldValue = self.currentValue,
      let newValue = event.newValue,
      !self.isDuplicate(oldValue, newValue)
    else { return }

    if let transaction = event.transaction {
      withTransaction(transaction) {
        self.objectWillChange.send()
        self.currentValue = newValue
      }
    } else {
      self.objectWillChange.send()
      self.currentValue = newValue
    }
  }

  func synchronize(with root: ObjectType) {
    self.currentValue = root[keyPath: self.keyPath]
    self.cancellable = nil

    let runLoopObserver = RunLoopObserver { [weak self] in
      guard let self = self else { return }
      while !self.pendingEvents.isEmpty {
        var event = self.pendingEvents.removeFirst()
        if let next = self.pendingEvents.first {
          event.newValue = next.oldValue
        } else {
          event.newValue = self.root?[keyPath: self.keyPath]
        }
        self.apply(event)
      }
    }

    let cancellable = root.objectWillChange.sink { [weak self] _ in
      guard let self = self else { return }
      let event = RootEvent(
        oldValue: self.root?[keyPath: self.keyPath],
        transaction: Transaction.current
      )
      self.pendingEvents.append(event)
    }

    self.cancellable = AnyCancellable {
      _ = (cancellable, runLoopObserver)
    }
  }

  struct RootEvent {
    var oldValue: Value?
    var newValue: Value?
    var transaction: Transaction?
  }
}
