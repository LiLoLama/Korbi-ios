import SwiftUI

struct RootView: View {
  @EnvironmentObject private var composition: CompositionRoot
  @EnvironmentObject private var appState: AppState

  var body: some View {
    Group {
      if appState.session == nil {
        AuthContainerView(viewModel: AuthViewModel(authService: composition.authService))
      } else {
        MainTabView()
      }
    }
    .task(id: appState.session?.userID) {
      if let userID = appState.session?.userID {
        await composition.householdService.refreshHouseholds()
        if let active = appState.activeHouseholdID {
          composition.realtimeService.subscribe(to: active)
          try? await composition.listsService.loadLists(for: active)
        }
        OSLog.auth.log("Signed in user: %{public}@", String(describing: userID))
      } else {
        composition.realtimeService.unsubscribe()
      }
    }
  }
}

private struct MainTabView: View {
  @EnvironmentObject private var composition: CompositionRoot
  @EnvironmentObject private var appState: AppState

  var body: some View {
    TabView {
      HomeView(viewModel: HomeViewModel(appState: appState, itemsService: composition.itemsService, voiceService: composition.voiceService))
        .tabItem { Label("Home", systemImage: "house") }

      ListsView(viewModel: ListsViewModel(appState: appState, itemsService: composition.itemsService, listsService: composition.listsService))
        .tabItem { Label("Listen", systemImage: "list.bullet") }

      HouseholdView(viewModel: HouseholdViewModel(appState: appState, householdService: composition.householdService))
        .tabItem { Label("Haushalt", systemImage: "person.2") }

      SettingsView(viewModel: SettingsViewModel(appState: appState, authService: composition.authService))
        .tabItem { Label("Einstellungen", systemImage: "gear") }
    }
    .tint(Tokens.tintPrimary)
    .background(Tokens.bgPrimary)
  }
}
