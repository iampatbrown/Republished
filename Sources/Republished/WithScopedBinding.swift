import Combine
import SwiftUI

public struct WithScopedBinding<ObjectType, Value, Content>: View
  where
  ObjectType: ObservableObject,
  ObjectType.ObjectWillChangePublisher == ObservableObjectPublisher,
  Content: View
{
  @ScopedBinding<ObjectType, Value> private var value: Value
  private let content: (Binding<Value>) -> Content

  public init(
    _ keyPath: ReferenceWritableKeyPath<ObjectType, Value>,
    removeDuplicates isDuplicate: @escaping (Value, Value) -> Bool,
    @ViewBuilder content: @escaping (Binding<Value>) -> Content
  ) {
    self._value = .init(keyPath, removeDuplicates: isDuplicate)
    self.content = content
  }

  public init(
    _ keyPath: ReferenceWritableKeyPath<ObjectType, Value>,
    @ViewBuilder content: @escaping (Binding<Value>) -> Content
  ) where Value: Equatable {
    self._value = .init(keyPath)
    self.content = content
  }

  public init(
    _ keyPath: ReferenceWritableKeyPath<ObjectType, Value>,
    @ViewBuilder content: @escaping (Binding<Value>) -> Content
  ) where Value: ObservableObject, Value.ObjectWillChangePublisher == ObservableObjectPublisher {
    self._value = .init(keyPath)
    self.content = content
  }

  public init<Wrapped>(
    _ keyPath: ReferenceWritableKeyPath<ObjectType, Wrapped?>,
    @ViewBuilder content: @escaping (Binding<Value>) -> Content
  ) where
    Wrapped? == Value,
    Wrapped: ObservableObject,
    Wrapped.ObjectWillChangePublisher == ObservableObjectPublisher
  {
    self._value = .init(keyPath)
    self.content = content
  }

  public init(
    _ keyPath: ReferenceWritableKeyPath<ObjectType, Value>,
    @ViewBuilder content: @escaping (Binding<Value>) -> Content
  ) where
    Value: Collection,
    Value.Element: ObservableObject,
    Value.Element.ObjectWillChangePublisher == ObservableObjectPublisher
  {
    self._value = .init(keyPath)
    self.content = content
  }

  public var body: some View {
    self.content($value)
  }
}
