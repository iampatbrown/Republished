import Combine
import DerivedBehavior
import Republished
import SwiftUI

class CounterViewModel: ObservableObject {
  @Published var alert: Alert?
  @Published var count = 0
  @Dependency(\.factClient) var fact
  @Dependency(\.mainQueue) var mainQueue
  let onFact: (Int, String) -> Void

  private var cancellables: Set<AnyCancellable> = []

  init(
    onFact: @escaping (Int, String) -> Void
  ) {
    self.onFact = onFact
  }

  struct Alert: Equatable, Identifiable {
    var message: String
    var title: String

    var id: String {
      self.title + self.message
    }
  }

  func decrementButtonTapped() {
    self.count -= 1
  }

  func incrementButtonTapped() {
    self.count += 1
  }

  func factButtonTapped() {
    self.fact.fetch(self.count)
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
      .store(in: &self.cancellables)
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
  @Republished var counter: CounterViewModel
  @Dependency(\.mainQueue) var mainQueue
  let id: UUID
  let onRemove: () -> Void

  var cancellable: AnyCancellable?

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
    self.cancellable = Just(())
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
    .buttonStyle(PlainButtonStyle())
  }
}

class FactPromptViewModel: ObservableObject {
  let count: Int
  @Published var fact: String
  @Published var isLoading = false
  @Dependency(\.factClient) var factClient
  @Dependency(\.mainQueue) var mainQueue

  private var cancellables: Set<AnyCancellable> = []

  init(
    count: Int,
    fact: String
  ) {
    self.count = count
    self.fact = fact
  }

  func getAnotherFactButtonTapped() {
    self.isLoading = true

    self.factClient.fetch(self.count)
      .receive(on: self.mainQueue.animation())
      .sink(
        receiveCompletion: { [weak self] _ in
          self?.isLoading = false
        },
        receiveValue: { [weak self] fact in
          self?.fact = fact
        }
      )
      .store(in: &self.cancellables)
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

struct IdentifiedArray<Element: Identifiable> {
  var ids: [Element.ID]
  var lookup: [Element.ID: Element]
}

class AppViewModel: ObservableObject {
  @Republished var counters: [CounterRowViewModel] = []
  @Republished var factPrompt: FactPromptViewModel?
  @Dependency(\.factClient) var fact
  @Dependency(\.uuid) var uuid

  private var cancellables: Set<AnyCancellable> = []

  var sum: Int {
    self.counters.reduce(0) { $0 + $1.counter.count }
  }

  func f() -> Int {
    1
  }

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
  @Scoped(\AppViewModel.sum) var sum
  @Scoped(\AppViewModel.counters) var counters
  @Scoped(\AppViewModel.factPrompt) var factPrompt
  @Action(AppViewModel.addButtonTapped) var addButtonTapped
  @Action(AppViewModel.dismissFactPrompt) var dismissFactPrompt

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

let action = AppViewModel.addButtonTapped

let action2 = AppViewModel.f
