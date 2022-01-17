import Combine
import SwiftUI

class ScopedObject<ObjectType, Value>: ObservableObject
  where
  ObjectType: ObservableObject,
  ObjectType.ObjectWillChangePublisher == ObservableObjectPublisher
{
  private weak var root: ObjectType?
  private let keyPath: KeyPath<ObjectType, Value>
  private var currentValue: Value?
  private var cancellable: AnyCancellable?

  private var pendingChanges: [Change] = []
  private let isDuplicate: (Value, Value) -> Bool

  private let subscribe: (ScopedObject, ObjectType) -> AnyCancellable?

  init(
    _ keyPath: KeyPath<ObjectType, Value>,
    removeDuplicates isDuplicate: @escaping (Value, Value) -> Bool
  ) {
    self.keyPath = keyPath
    self.isDuplicate = isDuplicate
    self.subscribe = { scoped, root in
      root.objectWillChange.sink { [weak scoped] _ in scoped?.enqueueChange() }
    }
  }

  init(
    _ keyPath: KeyPath<ObjectType, Value>
  )
    where Value: ObservableObject,
    Value.ObjectWillChangePublisher == ObservableObjectPublisher
  {
    self.keyPath = keyPath
    self.isDuplicate = { $0 === $1 }
    self.subscribe = { scoped, root in
      let rootCancellable = root.objectWillChange.sink { [weak scoped] _ in
        scoped?.enqueueChange()
      }
      let objectCancellable = root[keyPath: keyPath].objectWillChange.sink { [weak scoped] _ in
        scoped?.objectWillChange.send()
      }
      return AnyCancellable { _ = (rootCancellable, objectCancellable) }
    }
  }

  init<Wrapped>(_ keyPath: KeyPath<ObjectType, Wrapped?>)
    where
    Wrapped? == Value,
    Wrapped: ObservableObject,
    Wrapped.ObjectWillChangePublisher == ObservableObjectPublisher
  {
    self.keyPath = keyPath
    self.isDuplicate = { $0 === $1 }
    self.subscribe = { scoped, root in
      let rootCancellable = root.objectWillChange.sink { [weak scoped] _ in
        scoped?.enqueueChange()
      }
      let objectCancellable = root[keyPath: keyPath]?.objectWillChange.sink { [weak scoped] _ in
        scoped?.objectWillChange.send()
      }
      return AnyCancellable { _ = (rootCancellable, objectCancellable) }
    }
  }

  init(_ keyPath: KeyPath<ObjectType, Value>)
    where
    Value: Collection,
    Value.Element: ObservableObject,
    Value.Element.ObjectWillChangePublisher == ObservableObjectPublisher
  {
    self.keyPath = keyPath
    self.isDuplicate = { $0.count == $1.count && zip($0, $1).allSatisfy { $0.0 === $0.1 } }
    self.subscribe = { scoped, root in
      let rootCancellable = root.objectWillChange.sink { [weak scoped] _ in
        scoped?.enqueueChange()
      }
      let objectCancellables = root[keyPath: keyPath]
        .map { $0.objectWillChange.sink { [weak scoped] _ in
          scoped?.objectWillChange.send()
        } }
      return AnyCancellable { _ = (rootCancellable, objectCancellables) }
    }
  }

  var value: Value {
    guard let currentValue = self.currentValue else { fatalError() }
    return currentValue
  }

  private var rootValue: Value? { self.root?[keyPath: self.keyPath] }

  private func enqueueChange() {
    let change = Change(oldRootValue: self.rootValue, transcation: Transaction.current)
    self.pendingChanges.append(change)
  }

  private func applyPendingChanges() {
    while !self.pendingChanges.isEmpty {
      let change = self.pendingChanges.removeFirst()
      guard
        let oldValue = self.currentValue,
        let newValue = self.pendingChanges.first?.oldRootValue ?? self.rootValue,
        !self.isDuplicate(oldValue, newValue)
      else { continue }
      self.send(newValue, transaction: change.transcation)
    }
  }

  private func send(_ value: Value, transaction: SwiftUI.Transaction?) {
    if let transaction = transaction {
      withTransaction(transaction) {
        self.objectWillChange.send()
        self.currentValue = value
      }
    } else {
      self.objectWillChange.send()
      self.currentValue = value
    }
  }

  func subscribe(to root: ObjectType) -> AnyCancellable? {
    self.subscribe(self, root)
  }

  func synchronize(with root: ObjectType) {
    guard self.root !== root else { return }
    self.root = root
    self.currentValue = root[keyPath: self.keyPath]
    self.cancellable = nil

    let changeCancellable = self.subscribe(to: root)

    let runLoopObserver = RunLoopObserver { [weak self] in self?.applyPendingChanges() }

    self.cancellable = AnyCancellable {
      _ = (changeCancellable, runLoopObserver)
    }
  }

  struct Change {
    var oldRootValue: Value?
    var transcation: Transaction?
  }
}
