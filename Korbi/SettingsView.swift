import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: KorbiSettings
    @State private var isPresentingProfileEditor = false
    @State private var isPresentingShareSheet = false
    @State private var profileName = "Mia Berger"
    @State private var profileEmail = "mia@example.com"
    @State private var favoriteStore = "Biomarkt am Platz"
    @State private var enableNotifications = true
    @State private var inviteEmail = ""

    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Profil").font(KorbiTheme.Typography.title())) {
                    Button {
                        isPresentingProfileEditor = true
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

                    Button {
                        inviteEmail = ""
                        isPresentingShareSheet = true
                    } label: {
                        Label("Haushalt teilen", systemImage: "person.2.circle")
                            .font(KorbiTheme.Typography.body(weight: .semibold))
                            .foregroundStyle(settings.palette.primary)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(settings.palette.primary)
                    .controlSize(.large)
                    .clipShape(RoundedRectangle(cornerRadius: KorbiTheme.Metrics.compactCornerRadius, style: .continuous))
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
        .sheet(isPresented: $isPresentingProfileEditor) {
            ProfileEditorSheet(
                name: $profileName,
                email: $profileEmail,
                favoriteStore: $favoriteStore,
                notificationsEnabled: $enableNotifications,
                onDismiss: { isPresentingProfileEditor = false }
            )
            .environmentObject(settings)
        }
        .sheet(isPresented: $isPresentingShareSheet) {
            HouseholdShareSheet(
                householdName: settings.householdName,
                inviteEmail: $inviteEmail,
                onCancel: { isPresentingShareSheet = false },
                onSend: { isPresentingShareSheet = false }
            )
            .environmentObject(settings)
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(KorbiSettings())
}

private struct ProfileEditorSheet: View {
    @EnvironmentObject private var settings: KorbiSettings
    @Binding var name: String
    @Binding var email: String
    @Binding var favoriteStore: String
    @Binding var notificationsEnabled: Bool
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Profil")) {
                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.words)
                    TextField("E-Mail", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                }

                Section(
                    header: Text("Präferenzen"),
                    footer: Text("Diese Informationen helfen Korbi, Empfehlungen und Erinnerungen für dich zu personalisieren.")
                ) {
                    TextField("Lieblingsgeschäft", text: $favoriteStore)
                    Toggle("Push-Benachrichtigungen", isOn: $notificationsEnabled)
                        .tint(settings.palette.primary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(KorbiBackground())
            .navigationTitle("Profil konfigurieren")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fertig", action: onDismiss)
                }
            }
        }
    }
}

private struct HouseholdShareSheet: View {
    @EnvironmentObject private var settings: KorbiSettings
    let householdName: String
    @Binding var inviteEmail: String
    let onCancel: () -> Void
    let onSend: () -> Void

    private var isSendDisabled: Bool {
        inviteEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Haushalt teilen")) {
                    Text("Lade weitere Personen zu \(householdName) ein, damit ihr gemeinsam planen könnt.")
                        .font(KorbiTheme.Typography.body())
                        .foregroundStyle(settings.palette.textSecondary)
                        .padding(.vertical, 4)

                    TextField("E-Mail-Adresse", text: $inviteEmail)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                }

                Section(header: Text("Nachricht")) {
                    Text("Hallo! Ich möchte dich zu unserem Korbi-Haushalt einladen. So können wir gemeinsam Einkaufslisten und Routinen verwalten.")
                        .font(KorbiTheme.Typography.caption())
                        .foregroundStyle(settings.palette.textSecondary)
                        .padding(.vertical, 2)
                }
            }
            .scrollContentBackground(.hidden)
            .background(KorbiBackground())
            .navigationTitle("Einladung senden")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Senden", action: onSend)
                        .disabled(isSendDisabled)
                }
            }
        }
    }
}
