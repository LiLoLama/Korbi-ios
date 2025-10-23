import SwiftUI

@main
struct KorbiApp: App {
    @StateObject private var root = CompositionRoot()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(root)
                .environment(\.locale, Locale(identifier: "de_DE"))
        }
    }
}
