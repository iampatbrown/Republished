import Combine
import SwiftUI

/// A property wrapper type that can read and write a value on an environment object.
///
/// Description
///
/// Example
@propertyWrapper
public struct ScopedBinding<ObjectType, Value>: DynamicProperty
  where
  ObjectType: ObservableObject,
  ObjectType.ObjectWillChangePublisher == ObservableObjectPublisher
{
  @UnobservedEnvironmentObject private var root: ObjectType
  @StateObject private var scoped: ScopedObject<ObjectType, Value>
  private let keyPath: ReferenceWritableKeyPath<ObjectType, Value>

  /// Creates a binding to the specified environment object keyPath.
  /// - Parameters:
  ///   - keyPath: A writable key path to a value on an environment object.
  ///   - isDuplicate: A closure to evaluate whether two values are equivalent, for purposes of updating the view. Return true from
  ///   this closure to indicate that the second value is a duplicate of the first.
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

  /// The underlying value referenced by the scoped binding.
  public var wrappedValue: Value {
    get { self.scoped.value }
    nonmutating set { self.root[keyPath: self.keyPath] = newValue }
  }

  /// A projection of the scoped binding that returns a binding.
  public var projectedValue: Binding<Value> {
    ObservedObject(wrappedValue: self.root).projectedValue[dynamicMember: self.keyPath]
  }

  /// Updates the underlying value of the stored value.
  public func update() {
    self.scoped.synchronize(with: self.root)
  }
}
