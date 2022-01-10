import Combine
import SwiftUI

@propertyWrapper
public struct ScopedState<ObjectType, Value>: DynamicProperty
  where ObjectType: ObservableObject
{
  @UnobservedEnvironmentObject var object: ObjectType
  @StateObject var scoped: ScopedObject<ObjectType, Value>

  public init(
    _ keyPath: ReferenceWritableKeyPath<ObjectType, Value>
  ) {
    self._scoped = .init(wrappedValue: .init(keyPath))
  }

  public var wrappedValue: Value {
    get { self.scoped.value ?? self.object[keyPath: self.scoped.keyPath] }
    nonmutating set {
      guard let keyPath = self.scoped.keyPath as? ReferenceWritableKeyPath<ObjectType, Value> else { return }
      self.object[keyPath: keyPath] = newValue
    }
  }

  public var projectedValue: Binding<Value> {
    Binding(
      get: { self.wrappedValue },
      set: { self.$scoped.value.transaction($1).wrappedValue = $0 }
    )
  }

  public func update() {
    self.scoped.object = self.object
  }
}
