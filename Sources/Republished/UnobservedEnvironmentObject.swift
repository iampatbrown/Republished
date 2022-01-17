import SwiftUI

/// A property wrapper type for accessing an environment object without observing changes.
///
/// Description
///
/// Example
@propertyWrapper
public struct UnobservedEnvironmentObject<ObjectType>: DynamicProperty
where ObjectType: ObservableObject {
  /// The underlying value referenced by the unobserved environment  object.
  @Environment(unobserved: ObjectType.self) public var wrappedValue

  /// Creates an unobserved environment object.
  public init() {}
}

extension Environment {
  init(unobserved object: Value.Type) where Value: ObservableObject {
    self.init(\.[\Value.self])
  }
}

extension EnvironmentValues {
  subscript<ObjectType>(
    keyPath: KeyPath<ObjectType, ObjectType>
  ) -> ObjectType where ObjectType: ObservableObject {
    guard let object = self.extract(key: "StoreKey<\(ObjectType.self)>", as: ObjectType.self) else {
      fatalError(
        """
        No ObservableObject of type \(ObjectType.self) found. \
        A View.environmentObject(_:) for \(ObjectType
          .self) may be missing as an ancestor of this view.
        """
      )
    }
    return object
  }
}
