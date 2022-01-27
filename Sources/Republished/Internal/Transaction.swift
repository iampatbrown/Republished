import SwiftUI

private let threadTransactionData = unsafeBitCast(
  dlsym(
    dlopen(nil, RTLD_LAZY),
    "_threadTransactionData"
  ),
  to: (@convention(c) () -> Any?).self
)

extension Transaction {
  static var current: Transaction? {
    guard let head = threadTransactionData()
    else { return nil }

    var transaction = Transaction()
    var node: Any? = head

    while let element = node {
      let mirror = Mirror(reflecting: element)
      node = mirror.superclassMirror?.descendant("after", "some")
      let value = mirror.descendant("value")
      let typeDescription = String(describing: type(of: element))

      switch (value, typeDescription) {
      case let (isContinuous as Bool, "TypedElement<Key<ContinuousKey>>"):
        transaction.isContinuous = isContinuous

      case let (disablesAnimations as Bool, "TypedElement<Key<DisablesAnimationsKey>>"):
        transaction.disablesAnimations = disablesAnimations

      case let (animation as Animation, "TypedElement<Key<AnimationKey>>"):
        transaction.animation = animation

      default:
        print("Unknown Element \(typeDescription)")
      }
    }

    return transaction
  }
}
