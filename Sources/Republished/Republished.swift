import Combine
import SwiftUI


@propertyWrapper
public struct Republished<Value> {
  let subject: Subject

  public init(
    wrappedValue: Value,
    inheritDependencies: Bool = true
  )
    where
    Value: ObservableObject,
    Value.ObjectWillChangePublisher == ObservableObjectPublisher
  {
    self.subject = .init(wrappedValue, inheritDependencies: inheritDependencies)
  }

  public init<Wrapped>(
    wrappedValue: Wrapped?,
    inheritDependencies: Bool = true
  ) where
    Wrapped? == Value,
    Wrapped: ObservableObject,
    Wrapped.ObjectWillChangePublisher == ObservableObjectPublisher
  {
    self.subject = .init(wrappedValue, inheritDependencies: inheritDependencies)
  }

  public init(
    wrappedValue: Value,
    inheritDependencies: Bool = true
  ) where
    Value: Collection,
    Value.Element: ObservableObject,
    Value.Element.ObjectWillChangePublisher == ObservableObjectPublisher
  {
    self.subject = .init(wrappedValue, inheritDependencies: inheritDependencies)
  }

  @available(
    *,
    unavailable,
    message: "@Republished is only available on properties of classes"
  )
  public var wrappedValue: Value {
    get { fatalError() }
    set { fatalError() }
  }

  public var projectedValue: Publisher {
    get { Publisher(self.subject) }
    set {}
  }

  func republish<EnclosingSelf>(to object: EnclosingSelf)
    where EnclosingSelf: ObservableObject,
    EnclosingSelf.ObjectWillChangePublisher == ObservableObjectPublisher
  {
    guard self.subject.changePublisher == nil else { return }
    self.subject.changePublisher = object.objectWillChange
  }

  public static subscript<EnclosingSelf>(
    _enclosingInstance object: EnclosingSelf,
    wrapped wrappedKeyPath: ReferenceWritableKeyPath<EnclosingSelf, Value>,
    storage storageKeyPath: ReferenceWritableKeyPath<
      EnclosingSelf,
      Republished<Value>
    >
  ) -> Value
    where EnclosingSelf: ObservableObject,
    EnclosingSelf.ObjectWillChangePublisher == ObservableObjectPublisher
  {
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

    public func receive<S>(subscriber: S) where S: Subscriber,
      Never == S.Failure, Value == S.Input
    {
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


    func receive<S>(subscriber: S) where S: Subscriber, Never == S.Failure,
      Output == S.Input
    {
      self.$currentValue.subscribe(subscriber)
    }

    func republish(_ value: Value) {
      self.cancellable = nil
      let changeCancellable = self.subscribe(value, self)
      let dependenciesCancellable = self.inheritDependencies(value, self)
      self
        .cancellable = AnyCancellable {
          _ = (changeCancellable, dependenciesCancellable)
        }
    }
    
    
    
    init(_ initialValue: Value, inheritDependencies: Bool)
      where Value: ObservableObject,
      Value.ObjectWillChangePublisher == ObservableObjectPublisher
    {
      self._currentValue = .init(wrappedValue: initialValue)
      self.subscribe = { $0.subscribe($1) }
      self
        .inheritDependencies = {
          inheritDependencies ? $0.inheritDependencies(from: $1) : nil
        }
      self.republish(initialValue)
    }

    init<Wrapped>(_ initialValue: Wrapped?, inheritDependencies: Bool)
      where Wrapped: ObservableObject,
      Wrapped? == Value,
      Wrapped.ObjectWillChangePublisher == ObservableObjectPublisher
    {
      self._currentValue = .init(wrappedValue: initialValue)
      self.subscribe = { $0?.subscribe($1) }
      self
        .inheritDependencies = {
          inheritDependencies ? $0?.inheritDependencies(from: $1) : nil
        }
      self.republish(initialValue)
    }

    init(_ initialValue: Value, inheritDependencies: Bool)
      where Value: Collection, Value.Element: ObservableObject,
      Value.Element.ObjectWillChangePublisher == ObservableObjectPublisher
    {
      self._currentValue = .init(wrappedValue: initialValue)
      self.subscribe = { $0.subscribe($1) }
      self
        .inheritDependencies = {
          inheritDependencies ? $0.inheritDependencies(from: $1) : nil
        }
      self.republish(initialValue)
    }
  }
}

extension ObservableObject
  where ObjectWillChangePublisher == ObservableObjectPublisher
{
  func subscribe<Value>(_ subject: Republished<Value>
    .Subject) -> AnyCancellable
  {
    self.objectWillChange
      .sink { [weak subject] _ in subject?.changePublisher?.send() }
  }

  func inheritDependencies<Value>(from subject: Republished<Value>
    .Subject) -> AnyCancellable
  {
    Dependencies.bindInheritance(self) {
      [weak subject] in subject?.changePublisher.flatMap(ObjectIdentifier.init)
    }
  }
}

extension Collection where Element: ObservableObject,
  Element.ObjectWillChangePublisher == ObservableObjectPublisher
{
  func subscribe<Value>(_ subject: Republished<Value>
    .Subject) -> AnyCancellable
  {
    let cancellables = self.map { $0.subscribe(subject) }
    return AnyCancellable { _ = cancellables }
  }

  func inheritDependencies<Value>(from subject: Republished<Value>
    .Subject) -> AnyCancellable
  {
    let cancellables = self.map { $0.inheritDependencies(from: subject) }
    return AnyCancellable { _ = cancellables }
  }
}

extension Publisher where Failure == Never {
  public func assign(to republished: inout Republished<Output>.Publisher) {
    self.assign(to: &republished.subject.$currentValue)
  }
}



//private class RepublishedSubject<Output>: Publisher {
//  typealias Failure = Never
//
//  weak var rootObjectWillChange: ObservableObjectPublisher?
//
//  @Published var value: Output {
//    willSet { self.rootObjectWillChange?.send() }
//  }
//
//
//}
