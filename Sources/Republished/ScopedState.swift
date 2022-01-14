import Combine
import SwiftUI

@propertyWrapper
public struct ScopedState<ObjectType, Value>: DynamicProperty
  where ObjectType: ObservableObject, ObjectType.ObjectWillChangePublisher == ObservableObjectPublisher
{
  @UnobservedEnvironmentObject var root: ObjectType
  @StateObject var scoped: ScopedSubject<ObjectType, Value>

  public init(
    _ keyPath: ReferenceWritableKeyPath<ObjectType, Value>
  ) {
    self._scoped = .init(wrappedValue: .init(keyPath))
  }

  public var wrappedValue: Value {
    get { self.scoped.value }
    nonmutating set {
      self.scoped.value = newValue
    }
  }

  public var projectedValue: Binding<Value> {
    Binding(
      get: { self.wrappedValue },
      set: { self.$scoped.value.transaction($1).wrappedValue = $0 }
    )
  }

  public func update() {
    self.scoped.root = self.root
  }
}
