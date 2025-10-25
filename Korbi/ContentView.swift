import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var settings: KorbiSettings
    @EnvironmentObject private var authManager: AuthManager
    @EnvironmentObject private var inviteCoordinator: InviteCoordinator
    @Environment(\.scenePhase) private var scenePhase

    @State private var inviteAlert: InviteAlert? = nil

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
            guard authManager.isAuthenticated else { return }
            await settings.refreshActiveSession()
            inviteCoordinator.attemptProcessingIfPossible()
        }
        .onChange(of: scenePhase) { newPhase in
            guard newPhase == .active, authManager.isAuthenticated else { return }
            Task {
                await settings.refreshActiveSession()
            }
        }
        .onChange(of: authManager.isAuthenticated) { isAuthenticated in
            guard isAuthenticated else { return }
            inviteCoordinator.attemptProcessingIfPossible()
        }
        .onReceive(inviteCoordinator.$status) { status in
            switch status {
            case let .success(householdName):
                let name = householdName ?? "deinem Haushalt"
                inviteAlert = InviteAlert(
                    title: "Haushalt beigetreten",
                    message: "Du bist jetzt Teil von \(name).",
                    kind: .success(message: "Du bist jetzt Teil von \(name).")
                )
            case let .failure(message, _):
                inviteAlert = InviteAlert(
                    title: "Einladung fehlgeschlagen",
                    message: message,
                    kind: .failure(message: message)
                )
            default:
                break
            }
        }
        .overlay(alignment: .top) {
            if inviteCoordinator.status.isProcessing {
                InviteProcessingBanner()
                    .padding()
            }
        }
        .alert(item: $inviteAlert) { alert in
            switch alert.kind {
            case .success:
                return Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    dismissButton: .default(Text("Okay")) {
                        inviteCoordinator.clear()
                    }
                )
            case .failure:
                return Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    primaryButton: .default(Text("Erneut versuchen")) {
                        inviteCoordinator.retry()
                    },
                    secondaryButton: .cancel(Text("Neuen Link anfordern")) {
                        inviteCoordinator.clear()
                    }
                )
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
    let previewSettings = KorbiSettings()
    let previewAuth = AuthManager()
    previewSettings.configure(authManager: previewAuth)

    return ContentView()
        .environmentObject(previewSettings)
        .environmentObject(previewAuth)
        .environmentObject(InviteCoordinator(settings: previewSettings, authManager: previewAuth))
}

private struct InviteProcessingBanner: View {
    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
            Text("Einladung wird angenommen…")
                .font(KorbiTheme.Typography.body(weight: .medium))
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
