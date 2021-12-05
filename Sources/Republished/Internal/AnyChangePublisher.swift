import Combine

private enum Box<T> {}

private protocol AnyChangePublisher {
  static func changePublisher(for object: Any) -> AnyPublisher<Void, Never>?
}

extension Box: AnyChangePublisher where T: ObservableObject {
  fileprivate static func changePublisher(for object: Any) -> AnyPublisher<Void, Never>? {
    (object as? T).map { $0.objectWillChange.map { _ in }.eraseToAnyPublisher() }
  }
}

@usableFromInline
func changePublisher(for object: Any) -> AnyPublisher<Void, Never>? {
  func open<T>(_: T.Type) -> AnyPublisher<Void, Never>? {
    (Box<T>.self as? AnyChangePublisher.Type)?.changePublisher(for: object)
  }
  return _openExistential(type(of: object), do: open)
}
