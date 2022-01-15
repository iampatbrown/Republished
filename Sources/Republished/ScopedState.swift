import Combine
import SwiftUI

@propertyWrapper
public struct ScopedState<ObjectType, Value>: DynamicProperty
  where ObjectType: ObservableObject, ObjectType.ObjectWillChangePublisher == ObservableObjectPublisher
{
  @UnobservedEnvironmentObject var root: ObjectType
  @State var scoped: _ScopedSubject<ObjectType, Value>


  public init(
    _ keyPath: ReferenceWritableKeyPath<ObjectType, Value>
  ) {
    self._scoped = .init(wrappedValue: .init(keyPath))

  }



  public var wrappedValue: Value {
    get {
      let value = self.tap.value!
      print("GETTER \(value)")
      return value
    }
    nonmutating set {
      self.scoped.value = newValue
    }
  }

  public var projectedValue: Binding<Value> {
    Binding(
      get: { self.wrappedValue },
      set: { self.$scoped.value.transaction($1).wrappedValue = $0 }
    )
  }

  public mutating func update() {
    print("Update Before \(self.tap.value)")
    if self.scoped._root !== self.root {
      self.scoped.root = self.root
      tap.cancellable = nil
      tap.cancellable = self.scoped.objectWillChange.print().sink(receiveValue: { [weak tap] _ in
        print("hererleroelroel")
        tap?.tap = ()
      })
    }
    self.tap.value = self.scoped.value
    print("Update After \(self.tap.value)")
  }

  @StateObject var tap = Tap()

  class Tap: ObservableObject {
    var value: Value?
    var cancellable: AnyCancellable?
    @Published var tap: Void = ()
  }
}
