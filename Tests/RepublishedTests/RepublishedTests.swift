import Combine
@testable import Republished
import XCTest

class Parent: ObservableObject {
  @Republished var child = Child()
}

 class ParentWithOptional: ObservableObject {
  @Republished var child: Child?
 }
//
// class ParentWithCollection: ObservableObject {
//  @Republished var children: [Child] = []
// }

class Child: ObservableObject {
  @Published var value = 0
}

final class RepublishedTests: XCTestCase {
  var cancellables: Set<AnyCancellable> = []

  func testBasic() throws {
    let parent = Parent()
    var values: [Int] = []

    let expectation = self.expectation(description: "ReceivedValue")
    parent.objectWillChange.sink { _ in
      DispatchQueue.main.async {
        values.append(parent.child.value)
        expectation.fulfill()
      }
    }.store(in: &self.cancellables)
    parent.child.value = 1

    self.wait(for: [expectation], timeout: 0.1)
    XCTAssertEqual(values, [1])
  }
}
