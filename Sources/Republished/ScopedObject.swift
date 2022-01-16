import Combine
import SwiftUI



protocol ObjectScope {
  associatedtype Root where Root: ObservableObject, Root.ObjectWillChangePublisher == ObservableObjectPublisher
  associatedtype Value
  func get(from root: Root) -> Value
}

protocol WrittableObjectScope: ObjectScope {
  func set(_ value: Value, on root: Root)
}

extension KeyPath: ObjectScope
  where Root: ObservableObject, Root.ObjectWillChangePublisher == ObservableObjectPublisher
{
  func get(from root: Root) -> Value {
    root[keyPath: self]
  }
}

extension ReferenceWritableKeyPath: WrittableObjectScope
  where Root: ObservableObject, Root.ObjectWillChangePublisher == ObservableObjectPublisher
{
  func set(_ value: Value, on root: Root) {
    root[keyPath: self] = value
  }
}

class ScopedObject<Scope: ObjectScope>: ObservableObject {
  let scope: Scope
  let isDuplicate: (Scope.Value, Scope.Value) -> Bool
  
  init(scope: Scope, isDuplicate: @escaping (Scope.Value, Scope.Value) -> Bool) {
    self.scope = scope
    self.isDuplicate = isDuplicate
  }
  
  var value: Scope.Value {
    fatalError()
  }

  
}
extension ScopedObject where Scope: WrittableObjectScope {
  var value: Scope.Value {
    get { fatalError() }
    set { }
  }
}

class ViewModel: ObservableObject {
  var count: Int = 0
  let count2: Int = 2
}

let scoped = ScopedObject(scope: \ViewModel.count, isDuplicate: ==)
let v = {
  scoped.value = 2
}()
