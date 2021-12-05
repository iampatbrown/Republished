import Combine
import SwiftUI

@propertyWrapper
public struct Republished<ObjectType> where ObjectType: ObservableObject {
  let relay = Relay()
  var observed: ObservedObject<ObjectType>

  public init(wrappedValue: ObjectType) {
    self.observed = ObservedObject(wrappedValue: wrappedValue)
  }

  @available(*, unavailable, message: "@Republished is only available on properties of classes")
  public var wrappedValue: ObjectType {
    get { fatalError() }
    set { fatalError() }
  }

  public var projectedValue: ObservedObject<ObjectType>.Wrapper {
    self.observed.projectedValue
  }

  public static subscript<EnclosingSelf: AnyObject>(
    _enclosingInstance object: EnclosingSelf,
    wrapped wrappedKeyPath: ReferenceWritableKeyPath<EnclosingSelf, ObjectType>,
    storage storageKeyPath: ReferenceWritableKeyPath<EnclosingSelf, Republished<ObjectType>>
  ) -> ObjectType {
    get {
      object[keyPath: storageKeyPath].republish(to: object)
      return object[keyPath: storageKeyPath].observed.wrappedValue
    }
    set {
      object[keyPath: storageKeyPath].republish(to: object)
      return object[keyPath: storageKeyPath].observed.wrappedValue = newValue
    }
  }

  private func republish<EnclosingSelf: AnyObject>(to object: EnclosingSelf) {
    guard self.relay.changePublisher == nil else { return }
    self.relay.changePublisher = observableObjectPublisher(for: object)
    self.relay.cancellable = self.observed.wrappedValue.objectWillChange.sink { _ in
      self.relay.changePublisher?.send()
    }
  }

  class Relay {
    var changePublisher: ObservableObjectPublisher?
    var cancellable: AnyCancellable?
  }
}
