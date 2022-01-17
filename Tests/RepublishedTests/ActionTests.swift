import Combine
@testable import Republished
import XCTest

private class Counter: ObservableObject {
  @Published var value = 0

  func increment() {
    self.value += 1
  }

  func decrement() {
    self.value -= 1
  }

  func voidReturnInt() -> Int { 42 }
  func voidReturnIntString() -> (Int, String) { (42, "Blob") }
  func intReturnVoid(_ n: Int) {}
  func intReturnString(_ n: Int) -> String { "Blob" }
  func intReturnIntString(_ n: Int) -> (Int, String) { (42, "Blob") }
  func intStringReturnString(_ n: Int, _ string: String) -> String { "Blob" }
  func intStringDoubleReturnIntString(_ n: Int, _ string: String,
                                      _ double: Double) -> (Int, String) { (42, "Blob") }
}

final class ActionTests: XCTestCase {
  var cancellables: Set<AnyCancellable> = []

  func testBasic() throws {
    let counter = Counter()

    withMockEnvironmentObjects(counter) {
      @Action(Counter.increment)
      var incrementCounter: () -> Void
      incrementCounter()
      XCTAssertEqual(counter.value, 1)

      @Action(Counter.decrement)
      var decrementCounter: () -> Void
      decrementCounter()
      XCTAssertEqual(counter.value, 0)

      @Action(Counter.voidReturnInt)
      var voidReturnInt: () -> Int
      XCTAssertEqual(voidReturnInt(), 42)

      @Action(Counter.voidReturnIntString)
      var voidReturnIntString: () -> (Int, String)
      XCTAssertTrue(voidReturnIntString() == (42, "Blob"))

      @Action(Counter.intReturnVoid)
      var intReturnVoid: (Int) -> Void
      XCTAssertTrue(intReturnVoid(42) == ())

      @Action(Counter.intReturnString)
      var intReturnString: (Int) -> String
      XCTAssertEqual(intReturnString(42), "Blob")

      @Action(Counter.intReturnIntString)
      var intReturnIntString: (Int) -> (Int, String)
      XCTAssertTrue(intReturnIntString(42) == (42, "Blob"))

      @Action(Counter.intStringReturnString)
      var intStringReturnString: (Int, String) -> String
      XCTAssertEqual(intStringReturnString(42, "Blob"), "Blob")

      @Action(Counter.intStringDoubleReturnIntString)
      var intStringDoubleReturnIntString: (Int, String, Double) -> (Int, String)
      XCTAssertTrue(intStringDoubleReturnIntString(42, "Blob", 42.0) == (42, "Blob"))
    }
  }
}
