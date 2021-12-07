import Foundation

extension NSRecursiveLock {
  @inlinable @discardableResult
  func sync<R>(work: () -> R) -> R {
    self.lock()
    defer { self.unlock() }
    return work()
  }
}

@propertyWrapper
class ThreadSafe<Value> {
  private var value: Value
  private let lock = NSRecursiveLock()

  public init(wrappedValue value: Value) {
    self.value = value
  }

  public var wrappedValue: Value {
    get { return lock.sync { return value } }
    set { lock.sync { value = newValue } }
  }
}
