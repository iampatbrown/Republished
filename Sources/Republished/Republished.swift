import Combine
import SwiftUI

@propertyWrapper
public struct Republished<Value> {
  let subject: Subject

  public init(
    wrappedValue: Value,
    inheritDependencies: Bool = true
  ) where Value: ObservableObject {
    self.subject = .init(wrappedValue) { $0.republish(to: $1, inheritDependencies: inheritDependencies) }
  }

  public init<Wrapped>(
    wrappedValue: Wrapped?,
    inheritDependencies: Bool = true
  ) where Wrapped? == Value, Wrapped: ObservableObject {
    self.subject = .init(wrappedValue) { $0?.republish(to: $1, inheritDependencies: inheritDependencies) }
  }

  public init(
    wrappedValue: Value,
    inheritDependencies: Bool = true
  ) where Value: Collection, Value.Element: ObservableObject {
    self.subject = .init(wrappedValue) { $0.republish(to: $1, inheritDependencies: inheritDependencies) }
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
    self.subject.changePublisher = observableObjectPublisher(for: object) ?? ObservableObjectPublisher()
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

    var cancellable: AnyCancellable?
    weak var changePublisher: ObservableObjectPublisher?
    var republishChanges: (Value, Subject) -> Void

    @Published var currentValue: Value {
      willSet { self.changePublisher?.send() }
      didSet { self.republishChanges(for: currentValue) }
    }

    init(_ initialValue: Value, republishChanges: @escaping (Value, Subject) -> Void) {
      self._currentValue = .init(wrappedValue: initialValue)
      self.republishChanges = republishChanges
      self.republishChanges(for: initialValue)
    }

    func receive<S>(subscriber: S) where S: Subscriber, Never == S.Failure, Output == S.Input {
      self.$currentValue.subscribe(subscriber)
    }

    func republishChanges(for value: Value) {
      self.republishChanges(value, self)
    }
  }
}

extension ObservableObject {
  func republish(to subject: Republished<Self>.Subject, inheritDependencies: Bool) {
    subject.cancellable = nil
    let changeCancellable = self.objectWillChange.sink { [weak subject] _ in subject?.changePublisher?.send() }
    let dependencyCancellable = inheritDependencies ? Dependencies.bindInheritance(self) {
      [weak subject] in subject?.changePublisher.flatMap(Dependencies.id)
    } : nil
    subject.cancellable = AnyCancellable {
      _ = changeCancellable
      _ = dependencyCancellable
    }
  }

  func republish(to subject: Republished<Self?>.Subject, inheritDependencies: Bool) {
    subject.cancellable = nil
    let changeCancellable = self.objectWillChange.sink { [weak subject] _ in subject?.changePublisher?.send() }
    let dependencyCancellable = inheritDependencies ? Dependencies.bindInheritance(self) {
      [weak subject] in subject?.changePublisher.flatMap(Dependencies.id)
    } : nil
    subject.cancellable = AnyCancellable {
      _ = changeCancellable
      _ = dependencyCancellable
    }
  }
}

extension Collection where Element: ObservableObject {
  func republish(to subject: Republished<Self>.Subject, inheritDependencies: Bool) {
    subject.cancellable = nil
    let changeCancellables = self.map {
      $0.objectWillChange.sink { [weak subject] _ in subject?.changePublisher?.send() }
    }
    let dependencyCancellables = inheritDependencies ? self.map {
      Dependencies.bindInheritance($0) { [weak subject] in subject?.changePublisher.flatMap(Dependencies.id) }
    } : nil
    subject.cancellable = AnyCancellable {
      _ = changeCancellables
      _ = dependencyCancellables
    }
  }
}
