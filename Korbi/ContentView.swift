import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var settings: KorbiSettings
    @EnvironmentObject private var authManager: AuthManager

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
    }

    private var mainAppView: some View {
        Group {
            if settings.currentHousehold != nil {
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
            } else {
                InitialHouseholdSetupView()
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(KorbiSettings())
        .environmentObject(AuthManager())
}

private struct InitialHouseholdSetupView: View {
    @EnvironmentObject private var settings: KorbiSettings
    @State private var isPresentingCreateSheet = false
    @State private var householdName = ""

    var body: some View {
        NavigationStack {
            ZStack {
                KorbiBackground()

                VStack(spacing: 24) {
                    Image(systemName: "house.lodge")
                        .font(.system(size: 48, weight: .semibold))
                        .foregroundStyle(settings.palette.primary)

                    VStack(spacing: 12) {
                        Text("Willkommen bei Korbi")
                            .font(KorbiTheme.Typography.largeTitle())
                            .foregroundStyle(settings.palette.textPrimary)

                        Text("Lege deinen ersten Haushalt an, um gemeinsam Listen zu organisieren und Einkäufe zu planen.")
                            .font(KorbiTheme.Typography.body())
                            .foregroundStyle(settings.palette.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 24)

                    Button {
                        householdName = ""
                        isPresentingCreateSheet = true
                    } label: {
                        Label("Ersten Haushalt erstellen", systemImage: "plus.circle")
                            .font(KorbiTheme.Typography.body(weight: .semibold))
                            .padding(.vertical, 16)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(settings.palette.primary)
                    .controlSize(.large)
                    .clipShape(RoundedRectangle(cornerRadius: KorbiTheme.Metrics.cornerRadius, style: .continuous))
                    .padding(.horizontal, 24)
                }
            }
            .navigationTitle("Haushalt anlegen")
        }
        .sheet(isPresented: $isPresentingCreateSheet) {
            CreateHouseholdSheet(
                title: "Erster Haushalt",
                actionTitle: "Anlegen",
                householdName: $householdName,
                onCancel: { isPresentingCreateSheet = false },
                onCreate: { name in
                    settings.createHousehold(named: name)
                    isPresentingCreateSheet = false
                }
            )
            .environmentObject(settings)
        }
    }
}
