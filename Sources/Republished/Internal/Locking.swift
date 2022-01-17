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

  init(wrappedValue value: Value) {
    self.value = value
  }

  var wrappedValue: Value {
    get { self.lock.sync { self.value } }
    set { self.lock.sync { self.value = newValue } }
  }
}
