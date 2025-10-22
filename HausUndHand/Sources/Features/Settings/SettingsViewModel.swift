import Foundation

@MainActor
final class SettingsViewModel: ObservableObject {
  @Published var enableAnalytics: Bool = false
  private let appState: AppState
  private let authService: AuthServicing

  init(appState: AppState, authService: AuthServicing) {
    self.appState = appState
    self.authService = authService
  }

  func signOut() {
    Task {
      try? await authService.signOut()
    }
  }
}
