import Combine
import SwiftUI

@propertyWrapper
public struct Republished<Value> {
  let subject: Subject

  public init(
    wrappedValue: Value,
    inheritDependencies: Bool = true
  ) where Value: ObservableObject {
    self.subject = .init(wrappedValue, inheritDependencies: inheritDependencies)
  }

  public init<Wrapped>(
    wrappedValue: Wrapped?,
    inheritDependencies: Bool = true
  ) where Wrapped? == Value, Wrapped: ObservableObject {
    self.subject = .init(wrappedValue, inheritDependencies: inheritDependencies)
  }

  public init(
    wrappedValue: Value,
    inheritDependencies: Bool = true
  ) where Value: Collection, Value.Element: ObservableObject {
    self.subject = .init(wrappedValue, inheritDependencies: inheritDependencies)
  }

  @available(*, unavailable, message: "@Republished is only available on properties of classes")
  public var wrappedValue: Value {
    get { fatalError() }
    set { fatalError() }
  }

  public var projectedValue: Publisher {
    Publisher(self.subject)
  }

  func republish<EnclosingSelf: AnyObject>(to object: EnclosingSelf) {
    guard self.subject.changePublisher == nil else { return }
    self.subject.changePublisher = ObservableObjectPublisher.extract(from: object) ?? ObservableObjectPublisher()
  }

  public static subscript<EnclosingSelf: AnyObject>(
    _enclosingInstance object: EnclosingSelf,
    wrapped wrappedKeyPath: ReferenceWritableKeyPath<EnclosingSelf, Value>,
    storage storageKeyPath: ReferenceWritableKeyPath<EnclosingSelf, Republished<Value>>
  ) -> Value {
    get {
      object[keyPath: storageKeyPath].republish(to: object)
      return object[keyPath: storageKeyPath].subject.currentValue
    }
    set {
      object[keyPath: storageKeyPath].republish(to: object)
      object[keyPath: storageKeyPath].subject.currentValue = newValue
    }
  }

  public struct Publisher: Combine.Publisher {
    public typealias Output = Value
    public typealias Failure = Never

    let subject: Subject

    init(_ subject: Subject) {
      self.subject = subject
    }

    public func receive<S>(subscriber: S) where S: Subscriber, Never == S.Failure, Value == S.Input {
      self.subject.subscribe(subscriber)
    }
  }

  class Subject: Combine.Publisher {
    typealias Output = Value
    typealias Failure = Never

    weak var changePublisher: ObservableObjectPublisher?
    var cancellable: AnyCancellable?
    var subscribe: (Value, Subject) -> AnyCancellable?
    var inheritDependencies: (Value, Subject) -> AnyCancellable?

    @Published var currentValue: Value {
      willSet { self.changePublisher?.send() }
      didSet { self.republish(self.currentValue) }
    }

    init(_ initialValue: Value, inheritDependencies: Bool) where Value: ObservableObject {
      self._currentValue = .init(wrappedValue: initialValue)
      self.subscribe = { $0.subscribe($1) }
      self.inheritDependencies = { inheritDependencies ? $0.inheritDependencies(from: $1) : nil }
      self.republish(initialValue)
    }

    init<Wrapped>(_ initialValue: Wrapped?, inheritDependencies: Bool) where Wrapped: ObservableObject,
      Wrapped? == Value
    {
      self._currentValue = .init(wrappedValue: initialValue)
      self.subscribe = { $0?.subscribe($1) }
      self.inheritDependencies = { inheritDependencies ? $0?.inheritDependencies(from: $1) : nil }
      self.republish(initialValue)
    }

    init(_ initialValue: Value, inheritDependencies: Bool) where Value: Collection, Value.Element: ObservableObject {
      self._currentValue = .init(wrappedValue: initialValue)
      self.subscribe = { $0.subscribe($1) }
      self.inheritDependencies = { inheritDependencies ? $0.inheritDependencies(from: $1) : nil }
      self.republish(initialValue)
    }

    func receive<S>(subscriber: S) where S: Subscriber, Never == S.Failure, Output == S.Input {
      self.$currentValue.subscribe(subscriber)
    }

    func republish(_ value: Value) {
      // TODO: Double check if this needs to be set to nil before subscribing...
      self.cancellable = nil
      let changeCancellable = self.subscribe(value, self)
      let dependenciesCancellable = self.inheritDependencies(value, self)
      self.cancellable = AnyCancellable { _ = (changeCancellable, dependenciesCancellable) }
    }
  }
}

extension ObservableObject {
  func subscribe<Value>(_ subject: Republished<Value>.Subject) -> AnyCancellable {
    self.objectWillChange.sink { [weak subject] _ in subject?.changePublisher?.send() }
  }

  func inheritDependencies<Value>(from subject: Republished<Value>.Subject) -> AnyCancellable {
    Dependencies.bindInheritance(self) {
      [weak subject] in subject?.changePublisher.flatMap(Dependencies.id)
    }
  }
}

extension Collection where Element: ObservableObject {
  func subscribe<Value>(_ subject: Republished<Value>.Subject) -> AnyCancellable {
    let cancellables = self.map { $0.subscribe(subject) }
    return AnyCancellable { _ = cancellables }
  }

  func inheritDependencies<Value>(from subject: Republished<Value>.Subject) -> AnyCancellable {
    let cancellables = self.map { $0.inheritDependencies(from: subject) }
    return AnyCancellable { _ = cancellables }
  }
}
