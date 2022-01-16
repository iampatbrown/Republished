import Combine
import SwiftUI

@propertyWrapper
public struct ScopedValue<Scope: ObjectScope>: DynamicProperty {
  @UnobservedEnvironmentObject var root: Scope.Root
  @StateObject var scoped: ScopedObject<Scope>

  public init(_ scope: Scope, removeDuplicates isDuplicate: @escaping (Scope.Value, Scope.Value) -> Bool) {
    self._scoped = .init(wrappedValue: .init(scope: scope, isDuplicate: isDuplicate))
  }

  public init(_ scope: Scope) where Scope.Value: Equatable {
    self._scoped = .init(wrappedValue: .init(scope: scope))
  }

  public init(_ scope: Scope, removeDuplicates isDuplicate: @escaping (Scope.Value, Scope.Value) -> Bool)
    where Scope: WrittableObjectScope
  {
    self._scoped = .init(wrappedValue: .init(scope: scope, isDuplicate: isDuplicate))
  }

  public init(_ scope: Scope) where Scope.Value: Equatable, Scope: WrittableObjectScope {
    self._scoped = .init(wrappedValue: .init(scope: scope))
  }

  public var wrappedValue: Scope.Value {
    self.scoped.value
  }

  public func update() {
    self.scoped.root = self.root
  }
}

extension ScopedValue where Scope: WrittableObjectScope {
  public var wrappedValue: Scope.Value {
    get { self.scoped.value }
    nonmutating set { self.scoped.value = newValue }
  }
}

// @propertyWrapper
// public struct ScopedValue<ObjectType, Value>: DynamicProperty
//  where ObjectType: ObservableObject, ObjectType.ObjectWillChangePublisher == ObservableObjectPublisher
// {
//  @UnobservedEnvironmentObject var root: ObjectType
//  @StateObject var subject: Subject
//
//  public init(_ keyPath: KeyPath<ObjectType, Value>, removeDuplicates isDuplicate: @escaping (Value, Value) -> Bool) {
//    self._subject = .init(wrappedValue: .init(keyPath, isDuplicate: isDuplicate))
//  }
//
//  public init(_ keyPath: KeyPath<ObjectType, Value>) where Value: Equatable {
//    self._subject = .init(wrappedValue: .init(keyPath, isDuplicate: ==))
//  }
//
//  public var wrappedValue: Value {
//    self.subject.value
//  }
//
//  public func update() {
//    self.subject.root = self.root
//  }
//
//  class Subject: ObservableObject {
//    var currentValue: Value?
//    var synchronize: (Subject, ObjectType) -> Void
//    var cancellable: AnyCancellable?
//    var pendingEvents: [Event] = []
//
//    var isDuplicate: (Value, Value) -> Bool
//
//    weak var root: ObjectType? {
//      didSet {
//        guard oldValue !== root, let root = root else { return }
//        self.synchronize(self, root)
//      }
//    }
//
//    var value: Value {
//      guard let currentValue = currentValue else { fatalError() }
//      return currentValue
//    }
//
//    init(_ keyPath: KeyPath<ObjectType, Value>, isDuplicate: @escaping (Value, Value) -> Bool) {
//      self.synchronize = { $0.synchronize(with: keyPath, on: $1, isDuplicate: isDuplicate) }
//      self.isDuplicate = isDuplicate
//    }
//
//    func apply(_ event: Event) {
//      guard
//        let oldValue = self.currentValue,
//        let newValue = event.nextValue
//      else { return }
//      print("oldValue: \(oldValue), newValue: \(newValue)˚")
//      guard
//        !self.isDuplicate(oldValue, newValue)
//      else { return }
//
//      if let transaction = event.transaction {
//        withTransaction(transaction) {
//          self.objectWillChange.send()
//          self.currentValue = newValue
//        }
//      } else {
//        self.objectWillChange.send()
//        self.currentValue = newValue
//      }
//    }
//  }
//
//  struct Event {
//    var value: Value?
//    var nextValue: Value?
//    var transaction: Transaction?
//  }
// }
//
// extension ScopedValue.Subject {
//  func synchronize(
//    with keyPath: KeyPath<ObjectType, Value>,
//    on root: ObjectType,
//    isDuplicate: @escaping (Value, Value) -> Bool
//  ) {
//    self.currentValue = root[keyPath: keyPath]
//    self.cancellable = nil
//
//    let runLoopObserver = RunLoopObserver { [weak self] in
//      guard let self = self else { return }
//      while !self.pendingEvents.isEmpty {
//        var event = self.pendingEvents.removeFirst()
//        if let next = self.pendingEvents.first {
//          event.nextValue = next.value
//        } else {
//          event.nextValue = self.root?[keyPath: keyPath]
//        }
//        self.apply(event)
//      }
//    }
//
//    let cancellable = root.objectWillChange.sink { [weak self] _ in
//      guard let self = self else { return }
//      let event = ScopedValue.Event(
//        value: self.root?[keyPath: keyPath],
//        transaction: Transaction.current
//      )
//      self.pendingEvents.append(event)
//    }
//
//    self.cancellable = AnyCancellable {
//      _ = (cancellable, runLoopObserver)
//    }
//  }
// }
