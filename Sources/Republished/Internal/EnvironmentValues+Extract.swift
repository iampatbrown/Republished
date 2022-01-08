import SwiftUI

extension EnvironmentValues: Sequence {
  public struct Iterator: IteratorProtocol {
    var current: Any?

    init(_ environment: EnvironmentValues) {
      let mirror = Mirror(reflecting: environment)
      self.current = mirror.descendant("_plist", "elements", "some") ?? mirror.descendant("plist", "elements", "some")
    }

    public mutating func next() -> Any? {
      guard let value = self.current else { return nil }
      defer {
        let linkedListNode = Mirror(reflecting: value).superclassMirror
        self.current = linkedListNode?.descendant("after", "some")
      }
      return value
    }
  }

  public func makeIterator() -> Iterator { Iterator(self) }
}

extension EnvironmentValues {
  func extract<T>(key: String, as type: T.Type) -> T? {
    self.first(where: { self.environmentKey(for: $0) == key })
      .flatMap { Mirror(reflecting: $0).descendant("value") as? T }
  }

  func environmentKey(for value: Any) -> String? {
    let typeDescription = String(describing: type(of: value))
    guard
      let prefix = typeDescription.range(of: "TypedElement<EnvironmentPropertyKey<"),
      let suffix = typeDescription.range(of: ">>", options: .backwards) else { return nil }
    return String(typeDescription[prefix.upperBound..<suffix.lowerBound])
  }
}
