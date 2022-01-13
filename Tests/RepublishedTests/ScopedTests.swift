import Combine
@testable import Republished
import SwiftUI
import XCTest

private class Parent: ObservableObject {
  @Republished var child = Child()

  init(child: Child = Child()) {
    self._child = .init(wrappedValue: child)
  }
}

private class ParentWithOptional: ObservableObject {
  @Republished var child: Child?

  init(child: Child? = nil) {
    self._child = .init(wrappedValue: child)
  }
}

private class ParentWithCollection: ObservableObject {
  @Republished var children: [Child] = []
}

private class Child: ObservableObject {
  @Published var value: Int

  init(value: Int = 0) {
    self._value = .init(wrappedValue: value)
  }
}

final class ScopedTests: XCTestCase {
  var cancellables: Set<AnyCancellable> = []

  func testBasic() async throws {
    var oldValues: [Int?] = []

    let child0 = Child(value: 0)
    let child1 = Child(value: 1)
    let child2 = Child(value: 2)
    let root = Parent(child: child0)

    withMockEnvironmentObjects(root) {
      let scoped = ScopedSubject(\Parent.child)

      scoped.update()

      scoped.objectWillChange.sink { _ in
        oldValues.append(scoped.value.value)
      }.store(in: &self.cancellables)


      root.child = child1
      self.wait(for: 0.1)
      scoped.value = child2
      self.wait(for: 0.1)
      root.child = child0
      self.wait(for: 0.1)

      XCTAssertEqual(oldValues, [0, 1, 2])
    }
  }
}
