import Combine
import SwiftUI


@propertyWrapper
public struct ScopedValue<ObjectType, Value>: DynamicProperty
  where
  ObjectType: ObservableObject,
  ObjectType.ObjectWillChangePublisher == ObservableObjectPublisher
{
  @UnobservedEnvironmentObject private var root: ObjectType
  @StateObject private var scoped: ScopedObject<ObjectType, Value>


  public init(
    _ keyPath: KeyPath<ObjectType, Value>,
    removeDuplicates isDuplicate: @escaping (Value, Value) -> Bool
  ) {
    self._scoped = .init(wrappedValue: .init(keyPath, removeDuplicates: isDuplicate))
  }

  public init(_ keyPath: KeyPath<ObjectType, Value>) where Value: Equatable {
    self.init(keyPath, removeDuplicates: ==)
  }

  public init(
    _ keyPath: KeyPath<ObjectType, Value>
  ) where Value: ObservableObject, Value.ObjectWillChangePublisher == ObservableObjectPublisher {
    self._scoped = .init(wrappedValue: .init(keyPath))
  }

  public init<Wrapped>(
    _ keyPath: KeyPath<ObjectType, Wrapped?>
  ) where
    Wrapped? == Value,
    Wrapped: ObservableObject,
    Wrapped.ObjectWillChangePublisher == ObservableObjectPublisher
  {
    self._scoped = .init(wrappedValue: .init(keyPath))
  }

  public init(
    _ keyPath: KeyPath<ObjectType, Value>
  ) where
    Value: Collection,
    Value.Element: ObservableObject,
    Value.Element.ObjectWillChangePublisher == ObservableObjectPublisher
  {
    self._scoped = .init(wrappedValue: .init(keyPath))
  }

  public var wrappedValue: Value {
    self.scoped.value
  }

 
  public func update() {
    self.scoped.synchronize(with: self.root)
  }
}
