import Combine
import SwiftUI

@propertyWrapper
public struct ScopedState<ObjectType, Value>: DynamicProperty
  where ObjectType: ObservableObject
{
  @UnobservedEnvironmentObject var root: ObjectType
  @StateObject var state: State

  public init(
    _ keyPath: ReferenceWritableKeyPath<ObjectType, Value>
  ) {
    self._state = .init(wrappedValue: State(keyPath))
  }

  public var wrappedValue: Value {
    get { self.state.value ?? self.root[keyPath: self.state.keyPath] }
    nonmutating set { self.root[keyPath: self.state.keyPath] = newValue }
  }

  public var projectedValue: Binding<Value> {
    Binding(
      get: { self.wrappedValue },
      set: { self.$state.value.transaction($1).wrappedValue = $0 }
    )
  }

  public func update() {
    self.state.update(root: self.root)
  }

  class State: ObservableObject {
    weak var root: ObjectType?
    let keyPath: ReferenceWritableKeyPath<ObjectType, Value>
    var cancellable: AnyCancellable?
    var isSending: Bool = false

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
      if let changePublisher = observableObjectPublisher(for: root[keyPath: self.keyPath]) {
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
}
