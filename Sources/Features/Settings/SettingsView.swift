import SwiftUI

struct SettingsView: View {
    @StateObject var viewModel: SettingsViewModel

    init(viewModel: SettingsViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Darstellung") {
                    Picker("App-Modus", selection: $viewModel.selectedTheme) {
                        ForEach(CompositionRoot.AppTheme.allCases) { theme in
                            Text(theme.label).tag(theme)
                        }
                    }
                    .onChange(of: viewModel.selectedTheme) { _, newValue in
                        viewModel.updateTheme(newValue)
                    }
                }

                Section("Debug") {
                    Toggle("Leeren Zustand simulieren", isOn: $viewModel.simulateEmptyState)
                    Button("Fehler-Banner zeigen") {
                        viewModel.triggerErrorBanner()
                    }
                    Button("Ladezustand zeigen") {
                        viewModel.triggerLoadingBanner()
                    }
                }

                Section("Über Korbi") {
                    Text("UI-Prototyp mit Mock-Daten. Keine echten Backend-Aufrufe.")
                        .font(Typography.body)
                        .foregroundStyle(Tokens.textSecondary)
                        .accessibilityLabel("UI Prototyp mit Mock-Daten. Keine echten Backend-Aufrufe.")
                }
            }
            .navigationTitle("Einstellungen")
            .tint(Tokens.tintPrimary)
        }
    }
}

#Preview("SettingsView") {
    SettingsView(viewModel: SettingsViewModel(root: CompositionRoot()))
}
