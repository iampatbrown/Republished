import XCTest
import Foundation

extension XCTestCase {
  func sleep(_ seconds: TimeInterval) async -> Void {
    try? await Task.sleep(nanoseconds: UInt64(seconds * Double(NSEC_PER_SEC)))
  }
  
  func wait(for timeout: TimeInterval) {
    let expectation = self.expectation(description: "Wait")
    expectation.isInverted = true
    self.wait(for: [expectation], timeout: timeout)
  }
}

