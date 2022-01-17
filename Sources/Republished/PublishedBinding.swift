import Combine
import SwiftUI

/// A property wrapper type that can read and write a `@Published` or `@Republished` value on an environment object.
///
/// Description
///
/// Example
@propertyWrapper
public struct PublishedBinding<ObjectType, Value>: DynamicProperty
  where ObjectType: ObservableObject, ObjectType.ObjectWillChangePublisher == ObservableObjectPublisher
{
  @UnobservedEnvironmentObject var root: ObjectType
  @StateObject var subject: Subject

  public init(_ keyPath: ReferenceWritableKeyPath<ObjectType, Published<Value>.Publisher>) {
    self._subject = .init(wrappedValue: .init(keyPath))
  }

  public init(_ keyPath: ReferenceWritableKeyPath<ObjectType, Republished<Value>.Publisher>) {
    self._subject = .init(wrappedValue: .init(keyPath))
  }

  public var wrappedValue: Value {
    get { self.subject.value }
    nonmutating set { self.subject.value = newValue }
  }

  public var projectedValue: Binding<Value> {
    self.$subject.value
  }

  public func update() {
    self.subject.root = self.root
  }

  class Subject: ObservableObject {
    var currentValue: Value?
    let relay = PassthroughSubject<Value, Never>()
    var isSending = false
    var synchronize: (Subject, ObjectType) -> Void
    var cancellable: AnyCancellable?

    weak var root: ObjectType? {
      willSet {
        guard let root = root, root !== newValue else { return }
        self.objectWillChange.send()
      }
      didSet {
        guard oldValue !== root, let root = root else { return }
        self.synchronize(self, root)
      }
    }

    var value: Value {
      get {
        guard let currentValue = currentValue else { fatalError() }
        return currentValue
      }
      set { self.send(newValue) }
    }

    func send(_ value: Value) {
      self.isSending = true
      self.objectWillChange.send()
      self.currentValue = value
      self.relay.send(value)
      self.isSending = false
    }

    init(_ keyPath: ReferenceWritableKeyPath<ObjectType, Published<Value>.Publisher>) {
      self.synchronize = { $0.synchronize(with: &$1[keyPath: keyPath]) }
    }

    init(_ keyPath: ReferenceWritableKeyPath<ObjectType, Republished<Value>.Publisher>) {
      self.synchronize = { $0.synchronize(with: &$1[keyPath: keyPath]) }
    }
  }
}

extension PublishedBinding.Subject {
  func synchronize(with publisher: inout Published<Value>.Publisher) {
    _ = publisher.sink { self.currentValue = $0 }
    self.cancellable = nil
    self.relay.assign(to: &publisher)
    self.cancellable = publisher.dropFirst().sink { [weak self] newValue in
      guard let self = self, !self.isSending else { return }
      self.objectWillChange.send()
      self.currentValue = newValue
    }
  }

  func synchronize(with publisher: inout Republished<Value>.Publisher) {
    self.currentValue = publisher.subject.currentValue
    self.cancellable = nil
    self.relay.assign(to: &publisher)
    self.cancellable = publisher.dropFirst().sink { [weak self] newValue in
      guard let self = self, !self.isSending else { return }
      self.objectWillChange.send()
      self.currentValue = newValue
    }
  }
}
