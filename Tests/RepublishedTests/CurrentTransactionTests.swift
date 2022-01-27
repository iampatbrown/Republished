import Combine
@testable import Republished
import SwiftUI
import XCTest

final class CurrentTransactionTests: XCTestCase {
  func testGetCurrentTransaction() throws {
    XCTAssertNil(Transaction.current)

    withAnimation(.linear) {
      XCTAssertEqual(Transaction.current?.animation, .linear)
    }

    XCTAssertNil(Transaction.current)

    var transaction = Transaction()
    transaction.disablesAnimations = true
    transaction.isContinuous = true
    transaction.animation = .linear

    withTransaction(transaction) {
      XCTAssertEqual(Transaction.current?.disablesAnimations, true)
      XCTAssertEqual(Transaction.current?.isContinuous, true)
      XCTAssertEqual(Transaction.current?.animation, .linear)
    }

    XCTAssertNil(Transaction.current)
  }
}
