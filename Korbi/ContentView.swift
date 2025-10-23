import SwiftUI

struct ContentView: View {
    init() {
        UITabBar.appearance().backgroundColor = UIColor.clear
    }

    var body: some View {
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
        .tint(KorbiTheme.Colors.primary)
        .background(KorbiTheme.Colors.background)
    }
}

#Preview {
    ContentView()
}
