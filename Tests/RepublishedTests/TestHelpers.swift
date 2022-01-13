import Foundation
import XCTest

extension XCTestCase {
  func wait(for timeout: TimeInterval) {
    let expectation = self.expectation(description: "Wait")
    DispatchQueue.main.asyncAfter(deadline: .now() + timeout) {
      expectation.fulfill()
    }
    self.wait(for: [expectation], timeout: timeout + 1)
  }
}
