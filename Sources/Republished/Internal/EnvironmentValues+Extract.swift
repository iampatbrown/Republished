import SwiftUI

struct EnvironmentValuesSquence: Sequence {
  let values: EnvironmentValues

  struct Iterator: IteratorProtocol {
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

  func makeIterator() -> Iterator { Iterator(self.values) }
}

extension EnvironmentValues {
  func extract<T>(key: String, as type: T.Type) -> T? {
    #if DEBUG
    if ProcessInfo.isRunningUnitTests, let root = EnvironmentValues.mockObjects[key] as? T {
      return root
    }
    #endif

    return EnvironmentValuesSquence(values: self)
      .first(where: { self.environmentKey(for: $0) == key })
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

#if DEBUG
func withMockEnvironmentObjects<Result>(_ objects: AnyObject..., do body: () -> Result) -> Result {
  let keysAndValues = objects.map { ("StoreKey<\(type(of: $0))>", $0 as Any) }
  EnvironmentValues.mockObjects.push(keysAndValues)
  defer { EnvironmentValues.mockObjects.popLast() }
  return body()
}

extension EnvironmentValues {
  @ThreadSafe fileprivate static var mockObjects = Stack<String, Any>()
}
#endif
