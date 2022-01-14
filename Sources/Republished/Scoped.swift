import Combine
import SwiftUI

@propertyWrapper
public struct Scoped<ObjectType, Value>: DynamicProperty
  where ObjectType: ObservableObject, ObjectType.ObjectWillChangePublisher == ObservableObjectPublisher
{
  @UnobservedEnvironmentObject var root: ObjectType

  @StateObject var scoped: ScopedObject<ObjectType, Value>

  public init(
    _ keyPath: ReferenceWritableKeyPath<ObjectType, Published<Value>.Publisher>
  ) {
    self._scoped = .init(wrappedValue: .init(keyPath))
  }
  
  
  public init(
    _ keyPath: ReferenceWritableKeyPath<ObjectType, Republished<Value>.Publisher>
  ) {
    self._scoped = .init(wrappedValue: .init(keyPath))
  }
  

  public var wrappedValue: Value {
    self.scoped.currentValue
  }

  public func update() {
    if self.scoped.root == nil {
      self.scoped.root = self.root
    }
  }
}

class ScopedObject<ObjectType, Value>: ObservableObject where ObjectType: ObservableObject,
  ObjectType.ObjectWillChangePublisher == ObservableObjectPublisher
{
  var currentValue: Value!
  var cancellable: AnyCancellable?

  weak var root: ObjectType? {
    didSet {
      guard let root = root else {
        return
      }
      self.subscribe(root, self)
    }
  }

  var subscribe: (ObjectType, ScopedObject) -> Void

  init(
    _ keyPath: ReferenceWritableKeyPath<ObjectType, Published<Value>.Publisher>
  ) {
    self.subscribe = { root, subject in
      _ = root[keyPath: keyPath].sink { subject.currentValue = $0 }
      subject.cancellable = root[keyPath: keyPath]
        .dropFirst()
        .sink { [weak subject] newValue in
          subject?.objectWillChange.send()
          subject?.currentValue = newValue
        }
    }
  }
  
  init(
    _ keyPath: ReferenceWritableKeyPath<ObjectType, Republished<Value>.Publisher>
  ) {
    self.subscribe = { root, subject in
      _ = root[keyPath: keyPath].sink { subject.currentValue = $0 }
      subject.cancellable = root[keyPath: keyPath]
        .dropFirst()
        .sink { [weak subject] newValue in
          subject?.objectWillChange.send()
          subject?.currentValue = newValue
        }
    }
  }
}
