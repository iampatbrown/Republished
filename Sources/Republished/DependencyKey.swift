import Foundation

public protocol DependencyKey {
  associatedtype Value
  static var defaultValue: Value { get }
  static var testValue: Value { get }
  static var previewValue: Value { get }
}

extension DependencyKey {
  public static var testValue: Value { Self.defaultValue }
  public static var previewValue: Value { Self.defaultValue }
}

extension DependencyKey {
  static var environmentDefault: Value {
    #if DEBUG
    if ProcessInfo.isRunningUnitTests { return Self.testValue }
    else if ProcessInfo.isRunningPreviews { return Self.previewValue }
    #endif
    return Self.defaultValue
  }
}
