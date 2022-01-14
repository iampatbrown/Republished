private enum Box<T> {}

private protocol AnyEquatable {
  static func areEqual(_ lhs: Any, _ rhs: Any) -> Bool
}

extension Box: AnyEquatable where T: Equatable {
  fileprivate static func areEqual(_ lhs: Any, _ rhs: Any) -> Bool {
    lhs as? T == rhs as? T
  }
}

@usableFromInline
func areEqual(_ lhs: Any, _ rhs: Any) -> Bool {
  func open<LHS>(_: LHS.Type) -> Bool? {
    if let box = (Box<LHS>.self as? AnyEquatable.Type) {
      print("are equatablable")
      return box.areEqual(lhs, rhs)
    } else {
      print("not equatable")
      return nil
    }
    
  }
  return _openExistential(type(of: lhs), do: open) ?? false
}



