import Combine
import SwiftUI

@propertyWrapper
public struct WithDependencies<ObjectType: AnyObject>: DynamicProperty {
  @State
  var storage: Storage

  public init(wrappedValue thunk: @autoclosure @escaping () -> ObjectType, _ dependencies: Dependencies) {
    self._storage = State(wrappedValue: Storage(state: .initially(thunk, dependencies)))
  }

  public var wrappedValue: ObjectType {
    switch storage.state {
    case let .initially(thunk, dependencies):
      let object = withDependencies(dependencies, thunk)
      storage.cancellable = Dependencies.bind(dependencies, to: object)
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

public func withDependencies<Result>(_ dependencies: Dependencies, _ body: () -> Result) -> Result {
  Dependencies.shared.withDependencies(dependencies, body)
}
