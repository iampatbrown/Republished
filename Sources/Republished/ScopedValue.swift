import Combine
import SwiftUI

/// A property wrapper type that can observe a value on an environment object.
///
/// Description
///
/// Example
@propertyWrapper
public struct ScopedValue<ObjectType, Value>: DynamicProperty
  where
  ObjectType: ObservableObject,
  ObjectType.ObjectWillChangePublisher == ObservableObjectPublisher
{
  @UnobservedEnvironmentObject private var root: ObjectType
  @StateObject private var scoped: ScopedObject<ObjectType, Value>

  /// Creates a scoped value to the specified environment object keyPath.
  /// - Parameters:
  ///   - keyPath: A  key path to a value on an environment object.
  ///   - isDuplicate: A closure to evaluate whether two values are equivalent, for purposes of updating the view. Return true from
  ///   this closure to indicate that the second value is a duplicate of the first.
  public init(
    _ keyPath: KeyPath<ObjectType, Value>,
    removeDuplicates isDuplicate: @escaping (Value, Value) -> Bool
  ) {
    self._scoped = .init(wrappedValue: .init(keyPath, removeDuplicates: isDuplicate))
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

  /// The underlying value referenced by the scoped value.
  public var wrappedValue: Value {
    self.scoped.value
  }

  /// Updates the underlying value of the stored value.
  public func update() {
    self.scoped.synchronize(with: self.root)
  }
}

extension ScopedValue where Value: Equatable {
  /// Creates a scoped value to the specified environment object keyPath.
  /// - Parameter keyPath: A key path to a value on an environment object.
  public init(_ keyPath: KeyPath<ObjectType, Value>) where Value: Equatable {
    self.init(keyPath, removeDuplicates: ==)
  }
}
