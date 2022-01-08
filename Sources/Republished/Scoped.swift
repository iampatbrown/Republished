import Combine
import SwiftUI

@propertyWrapper
public struct Scoped<ObjectType, Value>: DynamicProperty
  where ObjectType: ObservableObject
{
  @UnobservedEnvironmentObject var root: ObjectType
  @StateObject var state: State

  public init(
    _ keyPath: KeyPath<ObjectType, Value>
  ) {
    self._state = .init(wrappedValue: State(keyPath))
  }

  public var wrappedValue: Value {
    self.state.value ?? self.root[keyPath: self.state.keyPath]
  }

  public func update() {
    self.state.update(root: self.root)
  }

  class State: ObservableObject {
    weak var root: ObjectType?
    let keyPath: KeyPath<ObjectType, Value>
    var cancellable: AnyCancellable?

    @Published var currentValue: Value?

    init(_ keyPath: KeyPath<ObjectType, Value>) {
      self.keyPath = keyPath
    }

    var value: Value? {
      self.currentValue ?? self.root?[keyPath: self.keyPath]
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
              let self = self, let newValue = root?[keyPath: self.keyPath],
              !isEqual(initialValue, newValue) else { return }
            self.currentValue = newValue
          }
        }
      }
    }
  }
}
