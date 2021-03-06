import Combine

import Republished
import SwiftUI

// Point-Free / 0150-derived-behavior-pt5
// https://github.com/pointfreeco/episode-code-samples/tree/main/0150-derived-behavior-pt5/

class CounterViewModel: ObservableObject {
  @Dependency(\.factClient) private var factClient
  @Dependency(\.mainQueue) private var mainQueue
  @Published var alert: Alert?
  @Published var count = 0
  private let onFact: (Int, String) -> Void
  private var fetchFactCancellable: AnyCancellable?

  init(onFact: @escaping (Int, String) -> Void) {
    self.onFact = onFact
  }

  func decrementButtonTapped() {
    self.count -= 1
  }

  func incrementButtonTapped() {
    self.count += 1
  }

  func factButtonTapped() {
    self.fetchFactCancellable = self.factClient.fetch(self.count)
      .receive(on: self.mainQueue.animation())
      .sink(
        receiveCompletion: { [weak self] completion in
          if case .failure = completion {
            self?.alert = .init(message: "Couldn't load fact", title: "Error")
          }
        },
        receiveValue: { [weak self] fact in
          guard let self = self else { return }
          self.onFact(self.count, fact)
        }
      )
  }

  struct Alert: Equatable, Identifiable {
    var message: String
    var title: String

    var id: String {
      self.title + self.message
    }
  }
}

struct CounterView: View {
  @ObservedObject var viewModel: CounterViewModel

  var body: some View {
    Self._printChanges()
    return VStack {
      HStack {
        Button("-") { self.viewModel.decrementButtonTapped() }
        Text("\(self.viewModel.count)")
        Button("+") { self.viewModel.incrementButtonTapped() }
      }

      Button("Fact") { self.viewModel.factButtonTapped() }
    }
    .alert(item: self.$viewModel.alert) { alert in
      Alert(
        title: Text(alert.title),
        message: Text(alert.message)
      )
    }
  }
}

class CounterRowViewModel: ObservableObject, Identifiable {
  @Dependency(\.mainQueue) private var mainQueue
  @Republished var counter: CounterViewModel
  let id: UUID
  private let onRemove: () -> Void
  private var removeCancellable: AnyCancellable?

  init(
    counter: CounterViewModel,
    id: UUID,
    onRemove: @escaping () -> Void
  ) {
    self.counter = counter
    self.id = id
    self.onRemove = onRemove
  }

  func removeButtonTapped() {
    self.removeCancellable = Just(())
      .delay(for: .seconds(1), scheduler: self.mainQueue.animation())
      .sink { [weak self] in self?.onRemove() }
  }
}

struct CounterRowView: View {
  let viewModel: CounterRowViewModel

  var body: some View {
    Self._printChanges()
    return HStack {
      CounterView(viewModel: viewModel.counter)

      Spacer()

      Button("Remove") {
        withAnimation {
          self.viewModel.removeButtonTapped()
        }
      }
    }
    .buttonStyle(.plain)
  }
}

class FactPromptViewModel: ObservableObject {
  @Dependency(\.factClient) private var factClient
  @Dependency(\.mainQueue) private var mainQueue
  let count: Int
  @Published var fact: String
  @Published var isLoading: Bool

  private var fetchFactCancellable: AnyCancellable?

  init(
    count: Int,
    fact: String,
    isLoading: Bool = false
  ) {
    self.count = count
    self.fact = fact
    self.isLoading = isLoading
  }

  func getAnotherFactButtonTapped() {
    self.isLoading = true

    self.fetchFactCancellable = self.factClient.fetch(self.count)
      .receive(on: self.mainQueue.animation())
      .sink(
        receiveCompletion: { [weak self] _ in
          self?.isLoading = false
        },
        receiveValue: { [weak self] fact in
          self?.fact = fact
        }
      )
  }
}

struct FactPrompt: View {
  @ObservedObject var viewModel: FactPromptViewModel
  let onDismissTapped: () -> Void

  var body: some View {
    Self._printChanges()
    return VStack(alignment: .leading, spacing: 16) {
      VStack(alignment: .leading, spacing: 12) {
        HStack {
          Image(systemName: "info.circle.fill")
          Text("Fact")
        }
        .font(.title3.bold())

        if self.viewModel.isLoading {
          ProgressView()
        } else {
          Text(self.viewModel.fact)
        }
      }

      HStack(spacing: 12) {
        Button("Get another fact") {
          self.viewModel.getAnotherFactButtonTapped()
        }

        Button("Dismiss") { self.onDismissTapped() }
      }
    }
    .padding()
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.white)
    .cornerRadius(8)
    .shadow(color: .black.opacity(0.1), radius: 20)
    .padding()
  }
}

class AppViewModel: ObservableObject {
  @Dependency(\.factClient) private var fact
  @Dependency(\.uuid) private var uuid
  @Republished var counters: [CounterRowViewModel] = []
  @Republished var factPrompt: FactPromptViewModel?

  private var cancellables: Set<AnyCancellable> = []

  var sum: Int { self.counters.reduce(0) { $0 + $1.counter.count } }

  func addButtonTapped() {
    let counterViewModel = CounterViewModel(
      onFact: { [weak self] count, fact in
        guard let self = self else { return }

        self.factPrompt = .init(
          count: count,
          fact: fact
        )
      }
    )

    let id = self.uuid()

    self.counters.append(
      .init(
        counter: counterViewModel,
        id: id,
        onRemove: { [weak self] in
          guard let self = self else { return }
          for (index, counter) in zip(self.counters.indices, self.counters) {
            if counter.id == id {
              self.counters.remove(at: index)
              return
            }
          }
        }
      )
    )
  }

  func dismissFactPrompt() {
    self.factPrompt = nil
  }
}

struct AppView: View {
  @ScopedValue(\AppViewModel.counters) var counters
  @ScopedValue(\AppViewModel.factPrompt) var factPrompt
  @ScopedValue(\AppViewModel.sum) var sum
  @ScopedAction(AppViewModel.addButtonTapped) var addButtonTapped
  @ScopedAction(AppViewModel.dismissFactPrompt) var dismissFactPrompt

  var body: some View {
    Self._printChanges()
    return ZStack(alignment: .bottom) {
      List {
        Text("Sum: \(self.sum)")
        ForEach(self.counters, content: CounterRowView.init)
      }
      .navigationTitle("Counters")
      .navigationBarItems(
        trailing: Button("Add") {
          withAnimation {
            self.addButtonTapped()
          }
        }
      )

      if let factPrompt = self.factPrompt {
        FactPrompt(
          viewModel: factPrompt,
          onDismissTapped: {
            self.dismissFactPrompt()
          }
        )
      }
    }
  }
}

struct _Previews: PreviewProvider {
  static var previews: some View {
    NavigationView {
      AppView().environmentObject(AppViewModel())
    }
  }
}
