import Combine
import SwiftUI

@propertyWrapper
public struct ScopedBinding<ObjectType, Value>: DynamicProperty
  where ObjectType: ObservableObject, ObjectType.ObjectWillChangePublisher == ObservableObjectPublisher
{
  @UnobservedEnvironmentObject var root: ObjectType
  @StateObject var subject: Subject

  public init(
    _ keyPath: ReferenceWritableKeyPath<ObjectType, Value>,
    removeDuplicates isDuplicate: @escaping (Value, Value) -> Bool
  ) {
    self._subject = .init(wrappedValue: .init(keyPath, isDuplicate: isDuplicate))
  }

  public init(_ keyPath: ReferenceWritableKeyPath<ObjectType, Value>) where Value: Equatable {
    self._subject = .init(wrappedValue: .init(keyPath, isDuplicate: ==))
  }

  public var wrappedValue: Value {
    get { self.subject.value }
    nonmutating set { self.subject.value = newValue }
  }

  public var projectedValue: Binding<Value> {
    self.$subject.value
  }

  public func update() {
    self.subject.root = self.root
  }

  class Subject: ObservableObject {
    let keyPath: ReferenceWritableKeyPath<ObjectType, Value>
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
      get {
        guard let currentValue = currentValue else { fatalError() }
        return currentValue
      }
      set {
        guard let root = root else { return }
        root[keyPath: self.keyPath] = newValue
      }
    }

    init(_ keyPath: ReferenceWritableKeyPath<ObjectType, Value>, isDuplicate: @escaping (Value, Value) -> Bool) {
      self.keyPath = keyPath
      self.synchronize = { subject, root in
        subject.currentValue = root[keyPath: keyPath]
        subject.cancellable = nil

        let runLoopObserver = RunLoopObserver { [weak subject] in
          guard let subject = subject, subject.requiresUpdate else { return }
          subject.requiresUpdate = false
          guard
            let oldValue = subject.currentValue,
            let newValue = subject.root?[keyPath: keyPath],
            !isDuplicate(oldValue, newValue)
          else { return }

          if let transaction = subject.transaction {
            withTransaction(transaction) {
              print("didChange.withTransaction")
              subject.objectWillChange.send()
              subject.currentValue = newValue
            }
          } else {
            print("didChange")
            subject.objectWillChange.send()
            subject.currentValue = newValue
          }
        }

        let cancellable = root.objectWillChange.print("mightChange").sink { [weak subject] _ in
          guard let subject = subject else { return }
          subject.requiresUpdate = true
          subject.transaction = Transaction.current
        }

        subject.cancellable = AnyCancellable {
          _ = (cancellable, runLoopObserver)
        }
      }
    }
  }
}
