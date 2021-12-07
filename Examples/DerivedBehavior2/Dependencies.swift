import CombineSchedulers
import Foundation
import Republished

extension Dependencies {
  static let live = Self {
    $0.factClient = .live
  }

  static let mock = Self {
    $0.factClient = .mock
  }

  static let failing = Self {
    $0.factClient = .failing
  }
}

private enum UUIDKey: DependencyKey {
  static let defaultValue: () -> UUID = UUID.init
}

extension Dependencies {
  public var uuid: () -> UUID {
    get { self[UUIDKey.self] }
    set { self[UUIDKey.self] = newValue }
  }
}

private enum MainQueueKey: DependencyKey {
  static let defaultValue = AnySchedulerOf<DispatchQueue>.main
  static let testValue = AnySchedulerOf<DispatchQueue>.immediate
}

extension Dependencies {
  public var mainQueue: AnySchedulerOf<DispatchQueue> {
    get { self[MainQueueKey.self] }
    set { self[MainQueueKey.self] = newValue }
  }
}
