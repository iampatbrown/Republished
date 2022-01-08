import Combine
@testable import Republished
import XCTest

private class Parent: ObservableObject {
  @Republished var child = Child()
}

private class ParentWithOptional: ObservableObject {
  @Republished var child: Child?
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

final class RepublishedTests: XCTestCase {
  var cancellables: Set<AnyCancellable> = []

  func testBasic() {
    let parent = Parent()
    var oldValues: [Int] = []

    let expectation = self.expectation(description: "ReceivedValue")
    expectation.expectedFulfillmentCount = 3

    parent.objectWillChange.sink {
      oldValues.append(parent.child.value)
      expectation.fulfill()
    }
    .store(in: &self.cancellables)

    parent.child.value = 1
    parent.child.value = 2
    parent.child.value = 3
    self.wait(for: [expectation], timeout: 0.1)
    XCTAssertEqual(oldValues, [0, 1, 2])
    XCTAssertEqual(parent.child.value, 3)
  }

  func testOptional() throws {
    let parent = ParentWithOptional()
    var oldValues: [Int?] = []

    let expectation = self.expectation(description: "ReceivedValue")
    expectation.expectedFulfillmentCount = 3
    parent.objectWillChange.sink {
      oldValues.append(parent.child?.value)
      expectation.fulfill()
    }
    .store(in: &self.cancellables)

    parent.child = Child(value: 1)
    parent.child = nil
    parent.child = Child(value: 3)

    self.wait(for: [expectation], timeout: 0.1)
    XCTAssertEqual(oldValues, [nil, 1, nil])
    XCTAssertEqual(parent.child?.value, 3)
  }

  func testOptionalSetWhileNil() throws {
    let parent = ParentWithOptional()
    var oldValues: [Int?] = []

    let expectation = self.expectation(description: "ReceivedValue")
    expectation.isInverted = true

    parent.objectWillChange.sink {
      oldValues.append(parent.child?.value)
      expectation.fulfill()
    }
    .store(in: &self.cancellables)

    parent.child?.value = 1

    self.wait(for: [expectation], timeout: 0.1)
    XCTAssertEqual(oldValues, [])
    XCTAssertNil(parent.child?.value)
  }

  func testCollection() throws {
    let parent = ParentWithCollection()
    var oldValues: [[Int]] = []

    let expectation = self.expectation(description: "ReceivedValue")
    expectation.expectedFulfillmentCount = 6

    parent.objectWillChange.sink {
      oldValues.append(parent.children.map(\.value))
      expectation.fulfill()

    }.store(in: &self.cancellables)

    let child1 = Child(value: 1)
    let child2 = Child(value: 2)
    let child3 = Child(value: 3)
    parent.children.append(child1)
    parent.children.first!.value = 11
    parent.children.append(child2)
    parent.children.append(child3)
    parent.children.last!.value = 33
    parent.children.removeFirst()

    self.wait(for: [expectation], timeout: 0.1)
    XCTAssertEqual(oldValues, [[], [1], [11], [11, 2], [11, 2, 3], [11, 2, 33]])
    XCTAssertEqual(parent.children.map(\.value), [2, 33])
  }
}
