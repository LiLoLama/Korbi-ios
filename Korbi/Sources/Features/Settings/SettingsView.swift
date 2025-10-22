import SwiftUI

struct SettingsView: View {
  @StateObject private var viewModel: SettingsViewModel
  @EnvironmentObject private var appState: AppState

  init(viewModel: SettingsViewModel) {
    _viewModel = StateObject(wrappedValue: viewModel)
  }

  var body: some View {
    NavigationStack {
      Form {
        Section(header: Text("Konto")) {
          if let email = appState.session?.email {
            Text(email)
              .font(FontTokens.body)
              .foregroundStyle(Tokens.textPrimary)
          }
          Button(role: .destructive, action: viewModel.signOut) {
            Text("Abmelden")
          }
        }

        Section(header: Text("Datenschutz"), footer: Text("Analytics sind standardmäßig deaktiviert. Bei Aktivierung werden anonyme Nutzungsdaten erfasst.")) {
          Toggle(isOn: $viewModel.enableAnalytics) {
            Text("Anonyme Nutzungsanalysen teilen")
          }
        }

        Section(header: Text("Über")) {
          HStack {
            Text("Version")
            Spacer()
            Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
          }
          Link(destination: URL(string: "https://supabase.com")!) {
            Label("Supabase", systemImage: "link")
          }
        }
      }
      .navigationTitle("Einstellungen")
    }
  }
}
