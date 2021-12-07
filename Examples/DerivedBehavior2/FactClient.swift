import Combine
import Foundation
import Republished

struct FactClient {
  var fetch: (Int) -> AnyPublisher<String, Error>

  struct Error: Swift.Error, Equatable {}
}

extension FactClient {
  static let live = Self(
    fetch: { number in
      URLSession.shared.dataTaskPublisher(for: URL(string: "http://numbersapi.com/\(number)")!)
        .map { data, _ in String(decoding: data, as: UTF8.self) }
        .mapError { _ in Error() }
        .eraseToAnyPublisher()
    }
  )

  static let mock = Self(
    fetch: { number in
      Just("\(number) is a number")
        .setFailureType(to: Error.self)
        .eraseToAnyPublisher()
    }
  )

  static let failing = Self(
    fetch: { _ in
      Fail(error: Error()).eraseToAnyPublisher()
    }
  )
}

private enum FactClientKey: DependencyKey {
  static let defaultValue = FactClient.mock
}

extension Dependencies {
  var factClient: FactClient {
    get { self[FactClientKey.self] }
    set { self[FactClientKey.self] = newValue }
  }
}
