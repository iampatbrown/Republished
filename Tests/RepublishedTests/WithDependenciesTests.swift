import Combine
@testable import Republished
import XCTest

private enum BlobKey: DependencyKey {
  static let defaultValue = "Blob"
  static let testValue = "TestBlob"
  static let previewValue = "PreviewBlob"
}

extension Dependencies {
  var blob: String {
    get { self[BlobKey.self] }
    set { self[BlobKey.self] = newValue }
  }
}

private class Parent: ObservableObject {
  @Dependency(\.blob) var blob
  let notRepublished = Child()
  @Republished var withInheritance = Child()
  @Republished(inheritDependencies: false) var withoutInheritance = Child()
}

private class Child: ObservableObject {
  @Dependency(\.blob) var blob
}

final class WithDependenciesTests: XCTestCase {
  var cancellables: Set<AnyCancellable> = []

  func testBasic() throws {
    let parent = Parent()

    XCTAssertEqual(parent.blob, BlobKey.testValue)

    withDependencies(Dependencies { $0.blob = "withBlob" }) {
      XCTAssertEqual(parent.blob, "withBlob")
    }

    XCTAssertEqual(parent.blob, BlobKey.testValue)
  }

  func testChildren() throws {
    let parent = Parent()

    XCTAssertEqual(parent.blob, BlobKey.testValue)
    XCTAssertEqual(parent.notRepublished.blob, BlobKey.testValue)
    XCTAssertEqual(parent.withInheritance.blob, BlobKey.testValue)
    XCTAssertEqual(parent.withoutInheritance.blob, BlobKey.testValue)

    withDependencies(Dependencies { $0.blob = "withBlob" }) {
      XCTAssertEqual(parent.blob, "withBlob")
      XCTAssertEqual(parent.notRepublished.blob, "withBlob")
      XCTAssertEqual(parent.withInheritance.blob, "withBlob")
      XCTAssertEqual(parent.withoutInheritance.blob, "withBlob")
    }

    XCTAssertEqual(parent.blob, BlobKey.testValue)
    XCTAssertEqual(parent.notRepublished.blob, BlobKey.testValue)
    XCTAssertEqual(parent.withInheritance.blob, BlobKey.testValue)
    XCTAssertEqual(parent.withoutInheritance.blob, BlobKey.testValue)
  }

  func testWithDependenciesWrapper() {
    @WithDependencies(Dependencies { $0.blob = "ParentBlob" }) var parent = Parent()
    XCTAssertEqual(parent.blob, "ParentBlob")
    XCTAssertEqual(parent.notRepublished.blob, BlobKey.testValue)
    XCTAssertEqual(parent.withInheritance.blob, "ParentBlob")
    XCTAssertEqual(parent.withoutInheritance.blob, BlobKey.testValue)

    withDependencies(Dependencies { $0.blob = "withBlob" }) {
      XCTAssertEqual(parent.blob, "withBlob")
      XCTAssertEqual(parent.notRepublished.blob, "withBlob")
      XCTAssertEqual(parent.withInheritance.blob, "withBlob")
      XCTAssertEqual(parent.withoutInheritance.blob, "withBlob")
    }

    XCTAssertEqual(parent.blob, "ParentBlob")
    XCTAssertEqual(parent.notRepublished.blob, BlobKey.testValue)
    XCTAssertEqual(parent.withInheritance.blob, "ParentBlob")
    XCTAssertEqual(parent.withoutInheritance.blob, BlobKey.testValue)
  }
}
