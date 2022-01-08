import Combine
@testable import Republished
import XCTest

enum Foo {
  case `default`
  case test
  case preview
  case wrapper
  case closure
}

private enum FooKey: DependencyKey {
  static let defaultValue = Foo.default
  static let testValue = Foo.test
  static let previewValue = Foo.preview
}

extension Dependencies {
  var foo: Foo {
    get { self[FooKey.self] }
    set { self[FooKey.self] = newValue }
  }
}

extension Dependencies {
  static var fooWrapper: Self { Self { $0.foo = .wrapper } }
  static var fooClosure: Self { Self { $0.foo = .closure } }
}

private class Parent: ObservableObject {
  @Dependency(\.foo) var foo
  let notRepublished = Child()
  @Republished var withInheritance = Child()
  @Republished(inheritDependencies: false) var withoutInheritance = Child()
}

private class Child: ObservableObject {
  @Dependency(\.foo) var foo
}

final class WithDependenciesTests: XCTestCase {
  var cancellables: Set<AnyCancellable> = []

  func testBasic() throws {
    let parent = Parent()

    XCTAssertEqual(parent.foo, .test)

    withDependencies(.fooClosure) {
      XCTAssertEqual(parent.foo, .closure)
    }

    XCTAssertEqual(parent.foo, .test)
  }

  func testChildren() throws {
    let parent = Parent()

    XCTAssertEqual(parent.foo, .test)
    XCTAssertEqual(parent.notRepublished.foo, .test)
    XCTAssertEqual(parent.withInheritance.foo, .test)
    XCTAssertEqual(parent.withoutInheritance.foo, .test)

    withDependencies(.fooClosure) {
      XCTAssertEqual(parent.foo, .closure)
      XCTAssertEqual(parent.notRepublished.foo, .closure)
      XCTAssertEqual(parent.withInheritance.foo, .closure)
      XCTAssertEqual(parent.withoutInheritance.foo, .closure)
    }

    XCTAssertEqual(parent.foo, .test)
    XCTAssertEqual(parent.notRepublished.foo, .test)
    XCTAssertEqual(parent.withInheritance.foo, .test)
    XCTAssertEqual(parent.withoutInheritance.foo, .test)
  }

  func testWithDependenciesWrapper() {
    @WithDependencies(.fooWrapper) var parent = Parent()
    XCTAssertEqual(parent.foo, .wrapper)
    XCTAssertEqual(parent.notRepublished.foo, .test)
    XCTAssertEqual(parent.withInheritance.foo, .wrapper)
    XCTAssertEqual(parent.withoutInheritance.foo, .test)

    withDependencies(.fooClosure) {
      XCTAssertEqual(parent.foo, .closure)
      XCTAssertEqual(parent.notRepublished.foo, .closure)
      XCTAssertEqual(parent.withInheritance.foo, .closure)
      XCTAssertEqual(parent.withoutInheritance.foo, .closure)
    }

    XCTAssertEqual(parent.foo, .wrapper)
    XCTAssertEqual(parent.notRepublished.foo, .test)
    XCTAssertEqual(parent.withInheritance.foo, .wrapper)
    XCTAssertEqual(parent.withoutInheritance.foo, .test)
  }
}
