import Combine
import SwiftUI

public struct WithScopedValue<ObjectType, Value, Content>: View
  where
  ObjectType: ObservableObject,
  ObjectType.ObjectWillChangePublisher == ObservableObjectPublisher,
  Content: View
{
  @ScopedValue<ObjectType, Value> private var value: Value
  private let content: (Value) -> Content

  public init(
    _ keyPath: KeyPath<ObjectType, Value>,
    removeDuplicates isDuplicate: @escaping (Value, Value) -> Bool,
    @ViewBuilder content: @escaping (Value) -> Content
  ) {
    self._value = .init(keyPath, removeDuplicates: isDuplicate)
    self.content = content
  }

  public init(
    _ keyPath: KeyPath<ObjectType, Value>,
    @ViewBuilder content: @escaping (Value) -> Content
  ) where Value: Equatable {
    self._value = .init(keyPath)
    self.content = content
  }

  public init(
    _ keyPath: KeyPath<ObjectType, Value>,
    @ViewBuilder content: @escaping (Value) -> Content
  ) where Value: ObservableObject, Value.ObjectWillChangePublisher == ObservableObjectPublisher {
    self._value = .init(keyPath)
    self.content = content
  }

  public init<Wrapped>(
    _ keyPath: KeyPath<ObjectType, Wrapped?>,
    @ViewBuilder content: @escaping (Value) -> Content
  ) where
    Wrapped? == Value,
    Wrapped: ObservableObject,
    Wrapped.ObjectWillChangePublisher == ObservableObjectPublisher
  {
    self._value = .init(keyPath)
    self.content = content
  }

  public init(
    _ keyPath: KeyPath<ObjectType, Value>,
    @ViewBuilder content: @escaping (Value) -> Content
  ) where
    Value: Collection,
    Value.Element: ObservableObject,
    Value.Element.ObjectWillChangePublisher == ObservableObjectPublisher
  {
    self._value = .init(keyPath)
    self.content = content
  }

  public var body: some View {
    self.content(value)
  }
}
