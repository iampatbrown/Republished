struct Stack<Key: Hashable, Value> {
  private var storage: [[Key: Value]] = [[:]]

  var size: Int { self.storage.count }
  
  
  subscript(key: Key) -> Value? {
    get { self.storage[self.storage.count - 1][key] }
    set { self.storage[self.storage.count - 1][key] = newValue }
  }

  mutating func push(_ other: Self) {
    self.storage.append(self.storage.last!)
    self.storage[self.storage.count - 1].merge(other.storage.last!) { $1 }
  }
  
  mutating func push(_ keysAndValues: [(Key, Value)]) {
    self.storage.append(self.storage.last!)
    self.storage[self.storage.count - 1].merge(keysAndValues) { $1 }
  }

  mutating func popLast() {
    self.storage.removeLast()
    if self.storage.isEmpty { self.storage.append([:]) }
  }
}
