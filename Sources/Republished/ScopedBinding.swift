import Combine
import SwiftUI

@propertyWrapper
public struct ScopedBinding<ObjectType, Value>: DynamicProperty
  where ObjectType: ObservableObject, ObjectType.ObjectWillChangePublisher == ObservableObjectPublisher
{
  @UnobservedEnvironmentObject var root: ObjectType
  @StateObject var scoped: ScopedObject<ObjectType, Value>
  let keyPath: ReferenceWritableKeyPath<ObjectType, Value>

  public init(
    _ keyPath: ReferenceWritableKeyPath<ObjectType, Value>,
    removeDuplicates isDuplicate: @escaping (Value, Value) -> Bool
  ) {
    self._scoped = .init(wrappedValue: .init(keyPath, isDuplicate: isDuplicate))
    self.keyPath = keyPath
  }

  public init(_ keyPath: ReferenceWritableKeyPath<ObjectType, Value>) where Value: Equatable {
    self._scoped = .init(wrappedValue: .init(keyPath))
    self.keyPath = keyPath
  }

  public var wrappedValue: Value {
    get { self.scoped.value }
    nonmutating set { self.root[keyPath: self.keyPath] = newValue }
  }

  public var projectedValue: Binding<Value> {
    ObservedObject(wrappedValue: self.root).projectedValue[dynamicMember: self.keyPath]
  }

  public func update() {
    self.scoped.root = self.root
  }
}
