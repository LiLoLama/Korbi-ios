import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: KorbiSettings

    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Profil").font(KorbiTheme.Typography.title())) {
                    Button {
                    } label: {
                        Label("Profil bearbeiten", systemImage: "person.crop.circle")
                            .font(KorbiTheme.Typography.body(weight: .semibold))
                            .foregroundStyle(settings.palette.primary)
                    }
                }

                Section(header: Text("Haushalt").font(KorbiTheme.Typography.title())) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Name")
                            .font(KorbiTheme.Typography.body(weight: .semibold))
                            .foregroundStyle(settings.palette.textSecondary)
                        TextField("Haushalt", text: $settings.householdName)
                            .font(KorbiTheme.Typography.body())
                    }
                    .padding(.vertical, 4)
                }

                Section(header: Text("Darstellung").font(KorbiTheme.Typography.title())) {
                    Toggle(isOn: $settings.useWarmLightMode) {
                        Label("Warmer Light Mode", systemImage: "sun.max.fill")
                            .font(KorbiTheme.Typography.body(weight: .semibold))
                    }
                    .tint(settings.palette.primary)

                    Text("Der warme Modus sorgt für freundliche, helle Farben – ideal für entspannte Einkaufsplanung am Tag.")
                        .font(KorbiTheme.Typography.caption())
                        .foregroundStyle(settings.palette.textSecondary)
                        .padding(.top, 4)
                }

                Section(header: Text("Mehr Korbi")) {
                    NavigationLink("Design Styleguide") {
                        StyleGuideView()
                    }
                    .font(KorbiTheme.Typography.body(weight: .medium))
                    .foregroundStyle(settings.palette.primary)

                    Button(role: .destructive) {
                    } label: {
                        Text("Abmelden")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(KorbiBackground())
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(settings.palette.background.opacity(0.9), for: .navigationBar)
            .navigationTitle("Einstellungen")
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(KorbiSettings())
}
