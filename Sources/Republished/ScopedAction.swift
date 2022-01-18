import Combine
import SwiftUI

@propertyWrapper
/// A property wrapper type that for a function on an environment object.
///
/// Does not observe changes
///
/// Example
public struct ScopedAction<ObjectType, Value>: DynamicProperty
  where ObjectType: ObservableObject
{
  @UnobservedEnvironmentObject var root: ObjectType
  let action: (ObjectType) -> Value

  public var wrappedValue: Value {
    self.action(self.root)
  }

  public init<Output>(
    _ action: @escaping (ObjectType) -> () -> Output
  ) where Value == () -> Output {
    self.action = action
  }

  public init<Input, Output>(
    _ action: @escaping (ObjectType) -> (Input) -> Output
  ) where Value == (Input) -> Output {
    self.action = action
  }

  public init<I1, I2, Output>(
    _ action: @escaping (ObjectType) -> (I1, I2) -> Output
  ) where Value == (I1, I2) -> Output {
    self.action = action
  }

  public init<I1, I2, I3, Output>(
    _ action: @escaping (ObjectType) -> (I1, I2, I3) -> Output
  ) where Value == (I1, I2, I3) -> Output {
    self.action = action
  }

  public init<I1, I2, I3, I4, Output>(
    _ action: @escaping (ObjectType) -> (I1, I2, I3, I4) -> Output
  ) where Value == (I1, I2, I3, I4) -> Output {
    self.action = action
  }

  public init<I1, I2, I3, I4, I5, Output>(
    _ action: @escaping (ObjectType) -> (I1, I2, I3, I4, I5) -> Output
  ) where Value == (I1, I2, I3, I4, I5) -> Output {
    self.action = action
  }
}
