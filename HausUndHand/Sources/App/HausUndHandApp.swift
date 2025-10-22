import SwiftUI

@main
struct HausUndHandApp: App {
  @StateObject private var composition = CompositionRoot()

  var body: some Scene {
    WindowGroup {
      RootView()
        .environmentObject(composition)
        .environmentObject(composition.appState)
        .preferredColorScheme(nil)
    }
  }
}
