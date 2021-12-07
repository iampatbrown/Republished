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

  func testBasic() throws {
    let parent = Parent()
    var values: [Int] = []

    let expectation = self.expectation(description: "ReceivedValue")
    expectation.expectedFulfillmentCount = 3
    parent.objectWillChange.sink { _ in
      DispatchQueue.main.async {
        values.append(parent.child.value)
        expectation.fulfill()
      }
    }.store(in: &self.cancellables)
    parent.child.value = 1
    DispatchQueue.main.async {
      parent.child.value = 2
      DispatchQueue.main.async {
        parent.child.value = 3
      }
    }

    self.wait(for: [expectation], timeout: 0.1)
    XCTAssertEqual(values, [1, 2, 3])
  }

  func testOptional() throws {
    let parent = ParentWithOptional()
    var values: [Int?] = []

    let expectation = self.expectation(description: "ReceivedValue")
    expectation.expectedFulfillmentCount = 3
    parent.objectWillChange.sink { _ in
      DispatchQueue.main.async {
        values.append(parent.child?.value)
        expectation.fulfill()
      }
    }.store(in: &self.cancellables)

    parent.child = Child(value: 1)
    DispatchQueue.main.async {
      parent.child = nil
      DispatchQueue.main.async {
        parent.child = Child(value: 3)
      }
    }

    self.wait(for: [expectation], timeout: 0.1)
    XCTAssertEqual(values, [1, nil, 3])
  }

  func testOptionalSetWhileNil() throws {
    let parent = ParentWithOptional()
    var values: [Int?] = []

    let expectation = self.expectation(description: "ReceivedValue")
    expectation.isInverted = true
    parent.objectWillChange.sink { _ in
      DispatchQueue.main.async {
        values.append(parent.child?.value)
        expectation.fulfill()
      }
    }.store(in: &self.cancellables)

    parent.child?.value = 1

    self.wait(for: [expectation], timeout: 0.1)
    XCTAssertEqual(values, [])
  }

  func testCollection() throws {
    let parent = ParentWithCollection()
    var values: [[Int]] = []

    let expectation = self.expectation(description: "ReceivedValue")
    expectation.expectedFulfillmentCount = 6
    parent.objectWillChange.sink { _ in
      DispatchQueue.main.async {
        values.append(parent.children.map(\.value))
        expectation.fulfill()
      }
    }.store(in: &self.cancellables)

    let child1 = Child(value: 1)
    let child2 = Child(value: 2)
    let child3 = Child(value: 3)
    parent.children.append(child1)
    DispatchQueue.main.async {
      parent.children.first!.value = 11
      DispatchQueue.main.async {
        parent.children.append(child2)
        DispatchQueue.main.async {
          parent.children.append(child3)
          DispatchQueue.main.async {
            parent.children.last!.value = 33
            DispatchQueue.main.async {
              parent.children.removeFirst()
            }
          }
        }
      }
    }


    self.wait(for: [expectation], timeout: 0.1)
    XCTAssertEqual(values, [[1],[11],[11,2],[11,2,3],[11,2,33],[2,33]])
  }
}
