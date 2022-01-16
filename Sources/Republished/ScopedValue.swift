import Combine
import SwiftUI

@propertyWrapper
public struct ScopedValue<ObjectType, Value>: DynamicProperty
  where ObjectType: ObservableObject, ObjectType.ObjectWillChangePublisher == ObservableObjectPublisher
{
  @UnobservedEnvironmentObject var root: ObjectType
  @StateObject var subject: Subject

  public init(_ keyPath: KeyPath<ObjectType, Value>, removeDuplicates isDuplicate: @escaping (Value, Value) -> Bool) {
    self._subject = .init(wrappedValue: .init(keyPath, isDuplicate: isDuplicate))
  }

  public init(_ keyPath: KeyPath<ObjectType, Value>) where Value: Equatable {
    self._subject = .init(wrappedValue: .init(keyPath, isDuplicate: ==))
  }

  public var wrappedValue: Value {
    self.subject.value
  }

  public func update() {
    self.subject.root = self.root
  }

  class Subject: ObservableObject {
    var currentValue: Value?
    var synchronize: (Subject, ObjectType) -> Void
    private var requiresUpdate = false
    private var transaction: Transaction?
    var cancellable: AnyCancellable?

    weak var root: ObjectType? {
      didSet {
        guard oldValue !== root, let root = root else { return }
        self.synchronize(self, root)
      }
    }

    var value: Value {
      guard let currentValue = currentValue else { fatalError() }
      return currentValue
    }

    init(_ keyPath: KeyPath<ObjectType, Value>, isDuplicate: @escaping (Value, Value) -> Bool) {
      self.synchronize = { $0.synchronize(with: keyPath, on: $1, isDuplicate: isDuplicate) }
    }
  }
}

extension ScopedValue.Subject {
  func synchronize(
    with keyPath: KeyPath<ObjectType, Value>,
    on root: ObjectType,
    isDuplicate: @escaping (Value, Value) -> Bool
  ) {
    self.currentValue = root[keyPath: keyPath]
    self.cancellable = nil

    let runLoopObserver = RunLoopObserver { [weak self] in
      guard let self = self, self.requiresUpdate else { return }
      self.requiresUpdate = false
      guard
        let oldValue = self.currentValue,
        let newValue = self.root?[keyPath: keyPath],
        !isDuplicate(oldValue, newValue)
      else { return }

      if let transaction = self.transaction {
        withTransaction(transaction) {
          self.objectWillChange.send()
          self.currentValue = newValue
        }
      } else {
        self.objectWillChange.send()
        self.currentValue = newValue
      }
    }

    let cancellable = root.objectWillChange.sink { [weak self] _ in
      guard let self = self else { return }
      self.requiresUpdate = true
      self.transaction = Transaction.current
    }

    self.cancellable = AnyCancellable {
      _ = (cancellable, runLoopObserver)
    }
  }
}
