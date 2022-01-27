import Combine
import SwiftUI


@propertyWrapper
public struct ScopedBinding<ObjectType, Value>: DynamicProperty
  where
  ObjectType: ObservableObject,
  ObjectType.ObjectWillChangePublisher == ObservableObjectPublisher
{
  @UnobservedEnvironmentObject private var root: ObjectType
  @StateObject private var scoped: ScopedObject<ObjectType, Value>
  private let keyPath: ReferenceWritableKeyPath<ObjectType, Value>


  public init(
    _ keyPath: ReferenceWritableKeyPath<ObjectType, Value>,
    removeDuplicates isDuplicate: @escaping (Value, Value) -> Bool
  ) {
    self.keyPath = keyPath
    self._scoped = .init(wrappedValue: .init(keyPath, removeDuplicates: isDuplicate))
  }

  public init(
    _ keyPath: ReferenceWritableKeyPath<ObjectType, Value>
  ) where Value: ObservableObject, Value.ObjectWillChangePublisher == ObservableObjectPublisher {
    self.keyPath = keyPath
    self._scoped = .init(wrappedValue: .init(keyPath))
  }

  public init(_ keyPath: ReferenceWritableKeyPath<ObjectType, Value>) where Value: Equatable {
    self.init(keyPath, removeDuplicates: ==)
  }

  public init<Wrapped>(
    _ keyPath: ReferenceWritableKeyPath<ObjectType, Wrapped?>
  ) where
    Wrapped? == Value,
    Wrapped: ObservableObject,
    Wrapped.ObjectWillChangePublisher == ObservableObjectPublisher
  {
    self.keyPath = keyPath
    self._scoped = .init(wrappedValue: .init(keyPath))
  }

  public init(
    _ keyPath: ReferenceWritableKeyPath<ObjectType, Value>
  ) where
    Value: Collection,
    Value.Element: ObservableObject,
    Value.Element.ObjectWillChangePublisher == ObservableObjectPublisher
  {
    self.keyPath = keyPath
    self._scoped = .init(wrappedValue: .init(keyPath))
  }


  public var wrappedValue: Value {
    get { self.scoped.value }
    nonmutating set { self.root[keyPath: self.keyPath] = newValue }
  }

 
  public var projectedValue: Binding<Value> {
    ObservedObject(wrappedValue: self.root).projectedValue[dynamicMember: self.keyPath]
  }


  public func update() {
    self.scoped.synchronize(with: self.root)
  }
}
