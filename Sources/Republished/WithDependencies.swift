import Combine
import SwiftUI

/// Executes a closure with the specified dependencies and returns the result.
///
/// Description
///
/// Example
public func withDependencies<Result>(_ dependencies: Dependencies, _ body: () -> Result) -> Result {
  Dependencies.shared.push(dependencies)
  defer { Dependencies.shared.popLast() }
  return body()
}

/// A property wrapper type for injects dependencies into an `ObservableObject`
///
/// Description
///
/// Example
@propertyWrapper
public struct WithDependencies<ObjectType>: DynamicProperty
  where
  ObjectType: ObservableObject,
  ObjectType.ObjectWillChangePublisher == ObservableObjectPublisher
{
  @State var storage: Storage

  public init(
    wrappedValue thunk: @autoclosure @escaping () -> ObjectType,
    _ dependencies: Dependencies
  ) {
    self._storage = State(wrappedValue: Storage(state: .initially(thunk, dependencies)))
  }

  public var wrappedValue: ObjectType {
    switch self.storage.state {
    case let .initially(thunk, dependencies):
      let object = withDependencies(dependencies, thunk)
      self.storage.state = .object(object)
      self.storage.cancellable = Dependencies.bind(dependencies, to: object)
      return object
    case let .object(object):
      return object
    }
  }

  class Storage {
    var state: State
    var cancellable: AnyCancellable?

    enum State {
      case initially(() -> ObjectType, Dependencies)
      case object(ObjectType)
    }

    init(state: State) {
      self.state = state
    }
  }
}
