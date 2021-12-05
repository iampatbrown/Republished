import Combine
import SwiftUI

@propertyWrapper
public struct ScopedEnvironmentObject<ObjectType, Scope, Value>: DynamicProperty
  where ObjectType: ObservableObject, Scope: ObservableObject
{
  @UnobservedEnvironmentObject var root: ObjectType
  @StateObject var scoped: Scoped

  public init(
    _ scopeKeyPath: KeyPath<ObjectType, Scope>,
    value valueKeyPath: ReferenceWritableKeyPath<Scope, Value>
  ) {
    self._scoped = .init(wrappedValue: Scoped(scopeKeyPath: scopeKeyPath, valueKeyPath: valueKeyPath))
  }

  public init(
    _ scopeKeyPath: ReferenceWritableKeyPath<ObjectType, Scope>
  ) where Value == Scope {
    self._scoped = .init(wrappedValue: Scoped(scopeKeyPath: scopeKeyPath))
  }

  public var wrappedValue: Value {
    get { self.scoped.value ?? self.root[keyPath: self.scoped.keyPath] }
    nonmutating set { self.root[keyPath: self.scoped.keyPath] = newValue }
  }

  public var projectedValue: Binding<Value> {
    Binding(
      get: { self.wrappedValue },
      set: { self.$scoped.value.transaction($1).wrappedValue = $0 }
    )
  }

  public func update() {
    self.scoped.update(root: self.root)
  }

  class Scoped: ObservableObject {
    weak var root: ObjectType?
    let scopeKeyPath: KeyPath<ObjectType, Scope>
    var keyPath: ReferenceWritableKeyPath<ObjectType, Value>

    var cancellable: AnyCancellable?
    var isSending: Bool = false

    @Published var currentValue: Value?

    init(scopeKeyPath: KeyPath<ObjectType, Scope>, valueKeyPath: ReferenceWritableKeyPath<Scope, Value>) {
      self.scopeKeyPath = scopeKeyPath
      self.keyPath = scopeKeyPath.appending(path: valueKeyPath)
    }

    init(scopeKeyPath: ReferenceWritableKeyPath<ObjectType, Scope>) where Value == Scope {
      self.scopeKeyPath = scopeKeyPath
      self.keyPath = scopeKeyPath
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
      if let objectWillChange = changePublisher(for: root[keyPath: self.keyPath]) {
        self.cancellable = objectWillChange.sink { [weak self] in self?.objectWillChange.send() }
      } else {
        self.cancellable = root[keyPath: self.scopeKeyPath].objectWillChange.sink { [weak self, weak root] _ in
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
}
