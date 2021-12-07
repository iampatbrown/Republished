import Republished
import SwiftUI

@main
struct DerivedBehavior2App: App {
  @WithDependencies(.live) var viewModel = AppViewModel()

  var body: some Scene {
    WindowGroup {
      NavigationView {
        AppView()
      }
      .navigationViewStyle(.stack)
      .environmentObject(viewModel)
    }
  }
}
