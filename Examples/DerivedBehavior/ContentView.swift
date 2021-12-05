import Combine
import Republished
import SwiftUI

// Point-Free / 0146-derived-behavior-pt1
// https://github.com/pointfreeco/episode-code-samples/blob/main/0146-derived-behavior-pt1/

class AppViewModel: ObservableObject {
  @Republished var counter: CounterViewModel
  @Republished var profile: ProfileViewModel
  var cancellables: Set<AnyCancellable> = []

  init(
    counter: CounterViewModel = .init(),
    profile: ProfileViewModel = .init()
  ) {
    self.counter = counter
    self.profile = profile

    synchronize(&self.counter.$favorites, &self.profile.$favorites)
      .store(in: &self.cancellables)
  }
}

struct ContentView: View {
  @ScopedEnvironmentObject(\AppViewModel.counter, value: \.count) var count
  @ScopedEnvironmentObject(\AppViewModel.profile, value: \.favorites) var favorites
  var body: some View {
    let _ = Self._printChanges()
    TabView {
      CounterView()
        .tabItem { Text("Counter \(self.count)") }

      ProfileView()
        .tabItem { Text("Profile \(self.favorites.count)") }
    }
  }
}

class CounterViewModel: ObservableObject {
  @Published var count = 0
  @Published var favorites: Set<Int> = []
}

struct CounterView: View {
  @ScopedEnvironmentObject(\AppViewModel.counter) var viewModel
  var body: some View {
    let _ = Self._printChanges()
    VStack {
      HStack {
        Button("-") { self.viewModel.count -= 1 }
        Text("\(self.viewModel.count)")
        Button("+") { self.viewModel.count += 1 }
      }

      if self.viewModel.favorites.contains(self.viewModel.count) {
        Button("Remove") {
          self.viewModel.favorites.remove(self.viewModel.count)
        }
      } else {
        Button("Save") {
          self.viewModel.favorites.insert(self.viewModel.count)
        }
      }
    }
  }
}

class ProfileViewModel: ObservableObject {
  @Published var favorites: Set<Int> = []
}

struct ProfileView: View {
  @ScopedEnvironmentObject(\AppViewModel.profile) var viewModel

  var body: some View {
    let _ = Self._printChanges()
    List {
      ForEach(self.viewModel.favorites.sorted(), id: \.self) { number in
        HStack {
          Text("\(number)")
          Spacer()
          Button("Remove") {
            self.viewModel.favorites.remove(number)
          }
        }
      }
    }
  }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    ContentView()
      .environmentObject(AppViewModel())
  }
}
