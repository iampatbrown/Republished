import Combine
import Republished
import SwiftUI

// Point-Free / 0146-derived-behavior-pt1
// https://github.com/pointfreeco/episode-code-samples/blob/main/0146-derived-behavior-pt1/

class AppViewModel: ObservableObject {
  @Republished var counter: CounterViewModel = .init()
  @Republished var profile: ProfileViewModel = .init()
  var cancellables: Set<AnyCancellable> = []

  init() {
    synchronize(
      &self.counter.$favorites,
      &self.profile.$favorites
    ).store(in: &self.cancellables)
  }
}

struct ProfileTabItem: View {
  @ScopedValue(\AppViewModel.profile.favorites.count) var favoritesCount
  var body: some View {
    Self._printChanges()
    return Text("Profile \(self.favoritesCount)")
  }
}

struct ContentView: View {
  var body: some View {
    Self._printChanges()
    return TabView {
      CounterView()
        .tabItem {
          WithScopedValue(\AppViewModel.counter.count) { count in
            Text("Counter \(count)")
          }
        }

      ProfileView()
        .tabItem {
          ProfileTabItem()
        }
    }
  }
}

class CounterViewModel: ObservableObject {
  @Published var count = 0
  @Published var favorites: Set<Int> = []
}

struct CounterView: View {
  @ScopedValue(\AppViewModel.counter) var viewModel
  var body: some View {
    Self._printChanges()
    return VStack {
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
  @ScopedValue(\AppViewModel.profile) var viewModel

  var body: some View {
    Self._printChanges()
    return List {
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
