import Combine
import SwiftUI

@propertyWrapper
public struct ScopedValue<ObjectType, Value>: DynamicProperty
  where ObjectType: ObservableObject
{
  @UnobservedEnvironmentObject var object: ObjectType
  @StateObject var scoped: ScopedObject<ObjectType, Value>

  public init(
    _ keyPath: KeyPath<ObjectType, Value>
  ) {
    self._scoped = .init(wrappedValue: .init(keyPath))
  }
  
  public init(
    _ keyPath: KeyPath<ObjectType, Value>
  ) where Value: ObservableObject {
    self._scoped = .init(wrappedValue: .init(keyPath))
  }

  public var wrappedValue: Value {
    self.scoped.value ?? self.object[keyPath: self.scoped.keyPath]
  }

  public func update() {
    self.scoped.object = self.object
  }
  
//  class Scope<ObjectType, Value>: ObservableObject {
//    
//  }
}



