import SwiftUI

/// A property wrapper type for accessing an environment object without observing changes.
///
/// Description
///
/// Example
@propertyWrapper
public struct UnobservedEnvironmentObject<ObjectType>: DynamicProperty
where ObjectType: ObservableObject {
  @Environment(unobserved: ObjectType.self) private var object: ObjectType?

  /// The underlying value referenced by the unobserved environment  object.
  public var wrappedValue: ObjectType {
    guard let object = object else {
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

  /// Creates an unobserved environment object.
  public init() {}
}

extension Environment {
  init<Wrapped>(unobserved object: Wrapped.Type) where Wrapped? == Value,
    Wrapped: ObservableObject
  {
    self.init(\.[\Wrapped.self])
  }
}

extension EnvironmentValues {
  subscript<ObjectType>(
    keyPath: KeyPath<ObjectType, ObjectType>
  ) -> ObjectType? where ObjectType: ObservableObject {
    return self.extract(
      key: "StoreKey<\(ObjectType.self)>",
      as: ObjectType.self
    )
  }
}
