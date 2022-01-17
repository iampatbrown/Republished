import Combine
import SwiftUI

/// A property wrapper type that can observe a `@Published` or `@Republished` value on an environment object.
///
/// Description
///
/// Example
@propertyWrapper
public struct RepublishedValue<ObjectType, Value>: DynamicProperty
  where ObjectType: ObservableObject, ObjectType.ObjectWillChangePublisher == ObservableObjectPublisher
{
  @UnobservedEnvironmentObject var root: ObjectType
  @StateObject var subject: Subject

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

  class Subject: ObservableObject {
    var currentValue: Value?

    var synchronize: (Subject, ObjectType) -> Void
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
}

extension RepublishedValue.Subject {
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



