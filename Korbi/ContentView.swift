import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var settings: KorbiSettings
    @EnvironmentObject private var authManager: AuthManager
    @Environment(\.scenePhase) private var scenePhase

    init() {
        UITabBar.appearance().backgroundColor = UIColor.clear
    }

    var body: some View {
        Group {
            if authManager.isAuthenticated {
                mainAppView
                    .transition(.opacity.combined(with: .scale))
            } else {
                LoginView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: authManager.isAuthenticated)
        .task(id: authManager.session?.accessToken) {
            if let session = authManager.session {
                await settings.refreshData(with: session)
            }
        }
        .onChange(of: scenePhase) { newPhase in
            guard newPhase == .active, let session = authManager.session else { return }
            Task {
                await settings.refreshData(with: session)
            }
        }
    }

    private var mainAppView: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
            ListsView()
                .tabItem {
                    Label("Listen", systemImage: "list.bullet.rectangle.portrait")
                }
            HouseholdView()
                .tabItem {
                    Label("Haushalt", systemImage: "person.3.fill")
                }
            SettingsView()
                .tabItem {
                    Label("Einstellungen", systemImage: "gearshape.fill")
                }
        }
        .tint(settings.palette.primary)
        .background(settings.palette.background)
    }
}

#Preview {
    ContentView()
        .environmentObject(KorbiSettings())
        .environmentObject(AuthManager())
}
