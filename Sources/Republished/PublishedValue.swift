import Combine
import SwiftUI

@propertyWrapper
public struct PublishedValue<ObjectType, Value>: DynamicProperty
  where ObjectType: ObservableObject, ObjectType.ObjectWillChangePublisher == ObservableObjectPublisher
{
  @UnobservedEnvironmentObject var root: ObjectType
  @StateObject var subject: PublishedValueSubject<ObjectType, Value>

  public init(_ keyPath: KeyPath<ObjectType, Published<Value>.Publisher>) {
    self._subject = .init(wrappedValue: .init(keyPath))
  }

  public init(_ keyPath: KeyPath<ObjectType, Republished<Value>.Publisher>) {
    self._subject = .init(wrappedValue: .init(keyPath))
  }

  public var wrappedValue: Value {
    self.subject.value
  }

  public func update() {
    self.subject.root = self.root
  }
}

class PublishedValueSubject<ObjectType, Value>: ObservableObject
  where ObjectType: ObservableObject, ObjectType.ObjectWillChangePublisher == ObservableObjectPublisher
{
  var currentValue: Value?
  
  var synchronize: (PublishedValueSubject, ObjectType) -> Void
  var cancellable: AnyCancellable?

  weak var root: ObjectType? {
    didSet {
      guard oldValue !== root, let root = root else { return }
      self.synchronize(self, root)
    }
  }
  

  var value: Value {
    guard let currentValue = currentValue else { fatalError() }
    return currentValue
  }

  init(_ keyPath: KeyPath<ObjectType, Published<Value>.Publisher>) {
    self.synchronize = { $0.synchronize(with: $1[keyPath: keyPath]) }
  }

  init(_ keyPath: KeyPath<ObjectType, Republished<Value>.Publisher>) {
    self.synchronize = { $0.synchronize(with: $1[keyPath: keyPath]) }
  }
}

extension PublishedValueSubject {
  func synchronize(with publisher: Published<Value>.Publisher) {
    _ = publisher.sink { self.currentValue = $0 }
    self.cancellable = nil
    self.cancellable = publisher.dropFirst().sink { [weak self] newValue in
      guard let self = self else { return }
      self.objectWillChange.send()
      self.currentValue = newValue
    }
  }

  func synchronize(with publisher: Republished<Value>.Publisher) {
    self.currentValue = publisher.subject.currentValue
    self.cancellable = nil
    self.cancellable = publisher.dropFirst().sink { [weak self] newValue in
      guard let self = self else { return }
      self.objectWillChange.send()
      self.currentValue = newValue
    }
  }
}
