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

  func testBasicObject() async throws {
    var oldValues: [Int?] = []

    let child0 = Child(value: 0)
    let child1 = Child(value: 1)
    let child2 = Child(value: 2)
    let child3 = Child(value: 3)
    let root = Parent(child: child0)
    let root2 = Parent(child: child3)

    let scoped = ScopedSubject(\Parent.child)
    withMockEnvironmentObjects(root) {
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

      XCTAssertTrue(scoped.value === child0)
      withMockEnvironmentObjects(root2) {
        scoped.update()
        XCTAssertEqual(oldValues, [0, 1, 2, 0])
        XCTAssertTrue(scoped.value === child3)
      }
      scoped.update()
      XCTAssertEqual(oldValues, [0, 1, 2, 0, 3])
      XCTAssertTrue(scoped.value === child0)
    }
  }

  func testBasicValue() async throws {
    var oldValues: [Int?] = []

    let child0 = Child(value: 0)
    let child1 = Child(value: 1)
    let child2 = Child(value: 2)
    let child3 = Child(value: 3)
    let root = Parent(child: child0)
    let root2 = Parent(child: child3)

    let scoped = ScopedSubject(\Parent.child.value)
    withMockEnvironmentObjects(root) {
      scoped.update()

      scoped.objectWillChange.sink { _ in
        oldValues.append(scoped.value)
      }.store(in: &self.cancellables)

      root.child = child1
      self.wait(for: 0.1)
      scoped.value = 2
      self.wait(for: 0.1)
      root.child.value = 0
      self.wait(for: 0.1)

      XCTAssertEqual(oldValues, [0, 1, 2])

      XCTAssertTrue(scoped.value == 0)
      withMockEnvironmentObjects(root2) {
        scoped.update()
        XCTAssertEqual(oldValues, [0, 1, 2, 0])
        XCTAssertTrue(scoped.value == 3)
      }
      scoped.update()
      XCTAssertEqual(oldValues, [0, 1, 2, 0, 3])
      XCTAssertTrue(scoped.value == 0)
    }
  }
}
