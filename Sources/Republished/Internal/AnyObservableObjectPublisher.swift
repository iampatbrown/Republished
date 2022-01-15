import Combine
import SwiftUI

private enum Box<T> {}

private protocol AnyObservableObjectPublisher {
  static func observableObjectPublisher(for object: Any) -> ObservableObjectPublisher?
}

extension Box: AnyObservableObjectPublisher where T: ObservableObject,
  T.ObjectWillChangePublisher == ObservableObjectPublisher
{
  fileprivate static func observableObjectPublisher(for object: Any) -> ObservableObjectPublisher? {
    (object as? T).map(\.objectWillChange)
  }
}

extension ObservableObjectPublisher {
  @usableFromInline
  static func extract(from object: Any) -> ObservableObjectPublisher? {
    func open<T>(_: T.Type) -> ObservableObjectPublisher? {
      (Box<T>.self as? AnyObservableObjectPublisher.Type)?.observableObjectPublisher(for: object)
    }
    return _openExistential(type(of: object), do: open)
  }
}


