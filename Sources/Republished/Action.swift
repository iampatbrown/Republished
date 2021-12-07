import Combine
import SwiftUI

@propertyWrapper
public struct Action<ObjectType, Value>: DynamicProperty
  where ObjectType: ObservableObject
{
  @UnobservedEnvironmentObject var root: ObjectType
  let action: (ObjectType) -> Value

  public init<Input, Output>(
    _ action: @escaping (ObjectType) -> (Input) -> Output
  ) where Value == (Input) -> Output {
    self.action = action
  }

  public init<Input>(
    _ action: @escaping (ObjectType) -> (Input) -> Void
  ) where Value == (Input) -> Void {
    self.action = action
  }

  public init<Output>(
    _ action: @escaping (ObjectType) -> () -> (Output)
  ) where Value == () -> (Output) {
    self.action = action
  }

  public init(
    _ action: @escaping (ObjectType) -> () -> Void
  ) where Value == () -> Void {
    self.action = action
  }

  public var wrappedValue: Value {
    action(self.root)
  }
}
