import Combine
import SwiftUI

public protocol ObjectScope {
  associatedtype Root where Root: ObservableObject, Root.ObjectWillChangePublisher == ObservableObjectPublisher
  associatedtype Value
  func get(from root: Root) -> Value
}

public protocol WrittableObjectScope: ObjectScope {
  func set(_ value: Value, on root: Root)
}

extension KeyPath: ObjectScope
  where Root: ObservableObject, Root.ObjectWillChangePublisher == ObservableObjectPublisher
{
  public func get(from root: Root) -> Value {
    root[keyPath: self]
  }
}

extension ReferenceWritableKeyPath: WrittableObjectScope
  where Root: ObservableObject, Root.ObjectWillChangePublisher == ObservableObjectPublisher
{
  public func set(_ value: Value, on root: Root) {
    root[keyPath: self] = value
  }
}



class ScopedObject<Scope: ObjectScope>: ObservableObject {
  let scope: Scope
  var currentValue: Scope.Value?
  var pendingEvents: [RootEvent] = []
  var cancellable: AnyCancellable?
  let isDuplicate: (Scope.Value, Scope.Value) -> Bool

  weak var root: Scope.Root? {
    didSet {
      guard oldValue !== root, let root = root else { return }
      self.synchronize(with: root)
    }
  }

  var value: Scope.Value {
    guard let currentValue = self.currentValue else { fatalError() }
    return currentValue
  }

  init(scope: Scope, isDuplicate: @escaping (Scope.Value, Scope.Value) -> Bool) {
    self.scope = scope
    self.isDuplicate = isDuplicate
  }

  init(scope: Scope) where Scope.Value: Equatable {
    self.scope = scope
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

  func synchronize(with root: Scope.Root) {
    self.currentValue = self.scope.get(from: root)
    self.cancellable = nil

    let runLoopObserver = RunLoopObserver { [weak self] in
      guard let self = self else { return }
      while !self.pendingEvents.isEmpty {
        var event = self.pendingEvents.removeFirst()
        if let next = self.pendingEvents.first {
          event.newValue = next.oldValue
        } else {
          event.newValue = self.root.map(self.scope.get)
        }
        self.apply(event)
      }
    }

    let cancellable = root.objectWillChange.sink { [weak self] _ in
      guard let self = self else { return }
      let event = RootEvent(
        oldValue: self.root.map(self.scope.get),
        transaction: Transaction.current
      )
      self.pendingEvents.append(event)
    }

    self.cancellable = AnyCancellable {
      _ = (cancellable, runLoopObserver)
    }
  }

  struct RootEvent {
    var oldValue: Scope.Value?
    var newValue: Scope.Value?
    var transaction: Transaction?
  }
}

extension ScopedObject where Scope: WrittableObjectScope {
  var value: Scope.Value {
    get {
      guard let currentValue = self.currentValue else { fatalError() }
      return currentValue
    }
    set {
      guard let root = self.root else { return }
      self.scope.set(newValue, on: root)
    }
  }
}




