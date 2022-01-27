import SwiftUI


@propertyWrapper
public struct UnobservedEnvironmentObject<ObjectType>: DynamicProperty
where ObjectType: ObservableObject {
  @Environment(unobserved: ObjectType.self) private var object: ObjectType?


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
