import Combine
import SwiftUI

@propertyWrapper
public struct PublishedBinding<ObjectType, Value>: DynamicProperty
  where ObjectType: ObservableObject, ObjectType.ObjectWillChangePublisher == ObservableObjectPublisher
{
  @UnobservedEnvironmentObject var root: ObjectType
  @StateObject var subject: PublishedBindingSubject<ObjectType, Value>

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

  public func update() {
    self.subject.root = self.root
  }
}

class PublishedBindingSubject<ObjectType, Value>: ObservableObject
  where ObjectType: ObservableObject, ObjectType.ObjectWillChangePublisher == ObservableObjectPublisher
{
  var currentValue: Value?
  let relay = PassthroughSubject<Value, Never>()
  var isSending = false
  var synchronize: (PublishedBindingSubject, ObjectType) -> Void
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

extension PublishedBindingSubject {
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
