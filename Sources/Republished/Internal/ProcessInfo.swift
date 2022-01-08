import Foundation

extension ProcessInfo {
  static var isRunningXcodeTests: Bool {
    Self.processInfo.environment["XCTestConfigurationFilePath"] != nil
  }

  static var isRunningPackageTests: Bool {
    Self.processInfo.arguments.contains(where: { $0.hasSuffix("xctest") })
  }

  static var isRunningUnitTests: Bool {
    Self.isRunningXcodeTests || Self.isRunningPackageTests
  }

  static var isRunningPreviews: Bool {
    Self.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
  }
}
