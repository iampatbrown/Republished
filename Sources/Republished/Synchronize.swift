import Combine

class SynchronizingRelay<Value> {
  let subject = PassthroughSubject<Value, Never>()
  var currentSender: CombineIdentifier?

  func send(_ value: Value) {
    subject.send(value)
  }

  func synchronize(with publisher: inout Published<Value>.Publisher) -> AnyCancellable {
    let id = CombineIdentifier()
    self.subject.filter { [weak self] _ in self.map { $0.currentSender != id } ?? false }.assign(to: &publisher)
    return publisher.sink { [weak self] newValue in
      guard let self = self, self.currentSender == nil else { return }
      self.currentSender = id
      self.subject.send(newValue)
      self.currentSender = nil
    }
  }
}

public func synchronize<Value>(
  _ p0: inout Published<Value>.Publisher,
  _ p1: inout Published<Value>.Publisher
) -> AnyCancellable {
  let relay = SynchronizingRelay<Value>()
  let c0 = relay.synchronize(with: &p0)
  let c1 = relay.synchronize(with: &p1)

  return AnyCancellable {
    _ = relay
    _ = c0
    _ = c1
  }
}

public func synchronize<Value>(
  _ p0: inout Published<Value>.Publisher,
  _ p1: inout Published<Value>.Publisher,
  _ p2: inout Published<Value>.Publisher
) -> AnyCancellable {
  let relay = SynchronizingRelay<Value>()
  let c0 = relay.synchronize(with: &p0)
  let c1 = relay.synchronize(with: &p1)
  let c2 = relay.synchronize(with: &p2)

  return AnyCancellable {
    _ = relay
    _ = c0
    _ = c1
    _ = c2
  }
}

public func synchronize<Value>(
  _ p0: inout Published<Value>.Publisher,
  _ p1: inout Published<Value>.Publisher,
  _ p2: inout Published<Value>.Publisher,
  _ p3: inout Published<Value>.Publisher
) -> AnyCancellable {
  let relay = SynchronizingRelay<Value>()
  let c0 = relay.synchronize(with: &p0)
  let c1 = relay.synchronize(with: &p1)
  let c2 = relay.synchronize(with: &p2)
  let c3 = relay.synchronize(with: &p3)

  return AnyCancellable {
    _ = relay
    _ = c0
    _ = c1
    _ = c2
    _ = c3
  }
}

public func synchronize<Value>(
  _ p0: inout Published<Value>.Publisher,
  _ p1: inout Published<Value>.Publisher,
  _ p2: inout Published<Value>.Publisher,
  _ p3: inout Published<Value>.Publisher,
  _ p4: inout Published<Value>.Publisher
) -> AnyCancellable {
  let relay = SynchronizingRelay<Value>()
  let c0 = relay.synchronize(with: &p0)
  let c1 = relay.synchronize(with: &p1)
  let c2 = relay.synchronize(with: &p2)
  let c3 = relay.synchronize(with: &p3)
  let c4 = relay.synchronize(with: &p4)

  return AnyCancellable {
    _ = relay
    _ = c0
    _ = c1
    _ = c2
    _ = c3
    _ = c4
  }
}
