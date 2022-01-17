import Republished
import SwiftUI

@main
struct DerivedBehaviorApp: App {
  var body: some Scene {
    WindowGroup {
      ContentView()
        .environmentObject(AppViewModel())
    }
  }
}
