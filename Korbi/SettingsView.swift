import SwiftUI

struct SettingsOption: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let icon: String
}

struct SettingsView: View {
    private let preferences: [SettingsOption] = [
        .init(title: "Haushaltsprofil", subtitle: "Mitglieder & Rollen verwalten", icon: "person.3"),
        .init(title: "Benachrichtigungen", subtitle: "Push, E-Mail & wöchentliche Übersicht", icon: "bell.badge"),
        .init(title: "Listen-Templates", subtitle: "Saisonale Empfehlungen anpassen", icon: "square.grid.2x2"),
        .init(title: "Stil & Anzeige", subtitle: "Hell/Dunkel & Schriftgröße", icon: "sun.max")
    ]

    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Einstellungen").font(KorbiTheme.Typography.title())) {
                    ForEach(preferences) { option in
                        HStack(spacing: 16) {
                            Image(systemName: option.icon)
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(KorbiTheme.Colors.primary)
                                .frame(width: 44, height: 44)
                                .background(
                                    RoundedRectangle(cornerRadius: KorbiTheme.Metrics.compactCornerRadius, style: .continuous)
                                        .fill(KorbiTheme.Colors.primary.opacity(0.14))
                                )
                            VStack(alignment: .leading, spacing: 6) {
                                Text(option.title)
                                    .font(KorbiTheme.Typography.body(weight: .semibold))
                                Text(option.subtitle)
                                    .font(KorbiTheme.Typography.caption())
                                    .foregroundStyle(KorbiTheme.Colors.textSecondary)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }

                Section(header: Text("Mehr Korbi")) {
                    NavigationLink("Design Styleguide") {
                        StyleGuideView()
                    }
                    .font(KorbiTheme.Typography.body(weight: .medium))
                    .foregroundStyle(KorbiTheme.Colors.primary)

                    Button(role: .destructive) {
                    } label: {
                        Text("Abmelden")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(KorbiBackground())
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(KorbiTheme.Colors.background.opacity(0.9), for: .navigationBar)
            .navigationTitle("Einstellungen")
        }
    }
}

#Preview {
    SettingsView()
}
