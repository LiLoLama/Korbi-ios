import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var settings: KorbiSettings
    @EnvironmentObject private var authManager: AuthManager
    @State private var householdLoadError: String?

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
        .task(id: authManager.isAuthenticated) {
            await handleAuthenticationChange()
        }
    }

    private var mainAppView: some View {
        Group {
            if settings.currentHousehold != nil {
                ZStack(alignment: .top) {
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
                        SettingsScreen()
                            .tabItem {
                                Label("Einstellungen", systemImage: "gearshape.fill")
                            }
                    }
                    .tint(settings.palette.primary)
                    .background(settings.palette.background)

                    if let householdLoadError {
                        Text(householdLoadError)
                            .font(.footnote)
                            .foregroundStyle(Color.red)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color(uiColor: .systemBackground).opacity(0.92))
                            )
                            .padding(.top, 12)
                    }
                }
            } else {
                InitialHouseholdSetupView(createHouseholdAction: handleInitialHouseholdCreation)
            }
        }
    }

    private func handleAuthenticationChange() async {
        if authManager.isAuthenticated {
            await refreshHouseholds()
        } else {
            await MainActor.run {
                settings.replaceHouseholds([])
                householdLoadError = nil
            }
        }
    }

    private func refreshHouseholds() async {
        do {
            let households = try await authManager.fetchHouseholds()
            await MainActor.run {
                settings.replaceHouseholds(households)
                householdLoadError = nil
            }
        } catch {
            await MainActor.run {
                householdLoadError = "Haushalte konnten nicht geladen werden."
            }
        }
    }

    private func handleInitialHouseholdCreation(_ name: String) async -> Bool {
        do {
            if let household = try await authManager.createHousehold(named: name) {
                await MainActor.run {
                    settings.upsertHousehold(household)
                    householdLoadError = nil
                }
                return true
            }
            return false
        } catch {
            await MainActor.run {
                householdLoadError = "Der Haushalt konnte nicht erstellt werden."
            }
            return false
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
    @State private var creationError: String?
    let createHouseholdAction: (String) async -> Bool

    var body: some View {
        NavigationStack {
            ZStack {
                KorbiBackground()

                VStack(spacing: 24) {
                    if let creationError {
                        Text(creationError)
                            .font(KorbiTheme.Typography.caption())
                            .foregroundStyle(Color.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
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
            SettingsCreateHouseholdSheet(
                title: "Erster Haushalt",
                actionTitle: "Anlegen",
                householdName: $householdName,
                onCancel: { isPresentingCreateSheet = false },
                onCreate: { name in
                    Task {
                        let success = await createHouseholdAction(name)
                        if success {
                            creationError = nil
                            householdName = ""
                            isPresentingCreateSheet = false
                        } else {
                            creationError = "Der Haushalt konnte nicht erstellt werden. Bitte versuche es erneut."
                        }
                    }
                }
            )
            .environmentObject(settings)
        }
    }
}
