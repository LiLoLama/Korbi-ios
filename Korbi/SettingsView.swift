import SwiftUI

struct SettingsScreen: View {
    @EnvironmentObject private var settings: KorbiSettings
    @EnvironmentObject private var authManager: AuthManager
    @State private var isPresentingProfileEditor = false
    @State private var isPresentingShareSheet = false
    @State private var isPresentingCreateHousehold = false
    @State private var isPresentingDeleteHousehold = false
    @State private var profileName = ""
    @State private var profileEmail = ""
    @State private var favoriteStore = "Biomarkt am Platz"
    @State private var enableNotifications = true
    @State private var newHouseholdName = ""
    @State private var householdPendingDeletion: Household? = nil
    @State private var isConfirmingHouseholdDeletion = false
    @State private var inviteEmail = ""
    @State private var profileStatusMessage: String?
    @State private var householdActionError: String?
    @State private var isSavingProfile = false

    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Profil").font(KorbiTheme.Typography.title())) {
                    Button {
                        profileStatusMessage = nil
                        isPresentingProfileEditor = true
                    } label: {
                        Label("Profil bearbeiten", systemImage: "person.crop.circle")
                            .font(KorbiTheme.Typography.body(weight: .semibold))
                            .foregroundStyle(settings.palette.primary)
                    }

                    if let profileStatusMessage {
                        Text(profileStatusMessage)
                            .font(KorbiTheme.Typography.caption())
                            .foregroundStyle(settings.palette.primary)
                    }
                }

                Section(header: Text("Haushalt").font(KorbiTheme.Typography.title())) {
                    if let householdActionError {
                        Text(householdActionError)
                            .font(KorbiTheme.Typography.caption())
                            .foregroundStyle(Color.red)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Aktueller Haushalt")
                            .font(KorbiTheme.Typography.body(weight: .semibold))
                            .foregroundStyle(settings.palette.textSecondary)

                        if let household = settings.currentHousehold {
                            Text(household.name)
                                .font(KorbiTheme.Typography.body())
                        } else {
                            Text("Noch kein Haushalt angelegt")
                                .font(KorbiTheme.Typography.body())
                                .foregroundStyle(settings.palette.textSecondary)
                        }
                    }
                    .padding(.vertical, 4)

                    Button {
                        newHouseholdName = ""
                        isPresentingCreateHousehold = true
                    } label: {
                        Label("Neuen Haushalt erstellen", systemImage: "plus.circle")
                            .font(KorbiTheme.Typography.body(weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(settings.palette.primary)
                    .controlSize(.large)
                    .clipShape(RoundedRectangle(cornerRadius: KorbiTheme.Metrics.compactCornerRadius, style: .continuous))
                    .padding(.vertical, 2)

                    Button {
                        householdPendingDeletion = nil
                        isPresentingDeleteHousehold = true
                    } label: {
                        Label("Haushalt löschen", systemImage: "trash")
                            .font(KorbiTheme.Typography.body(weight: .semibold))
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .controlSize(.large)
                    .clipShape(RoundedRectangle(cornerRadius: KorbiTheme.Metrics.compactCornerRadius, style: .continuous))
                    .disabled(settings.households.isEmpty)

                    Button {
                        inviteEmail = ""
                        isPresentingShareSheet = true
                    } label: {
                        Label("Haushalt teilen", systemImage: "person.2.circle")
                            .font(KorbiTheme.Typography.body(weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(settings.palette.primary)
                    .controlSize(.large)
                    .clipShape(RoundedRectangle(cornerRadius: KorbiTheme.Metrics.compactCornerRadius, style: .continuous))
                    .disabled(settings.currentHousehold == nil)
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

                Section(header: Text("Konto")) {
                    if let email = authManager.currentUserEmail {
                        Label(email, systemImage: "envelope.fill")
                            .font(KorbiTheme.Typography.body(weight: .medium))
                            .foregroundStyle(settings.palette.textSecondary)
                    }

                    Button(role: .destructive) {
                        withAnimation(.easeInOut) {
                            authManager.logout()
                        }
                    } label: {
                        Text("Abmelden")
                            .font(KorbiTheme.Typography.body(weight: .semibold))
                    }
                }

                Section(header: Text("Mehr Korbi")) {
                    NavigationLink("Design Styleguide") {
                        StyleGuideView()
                    }
                    .font(KorbiTheme.Typography.body(weight: .medium))
                    .foregroundStyle(settings.palette.primary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(KorbiBackground())
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(settings.palette.background.opacity(0.9), for: .navigationBar)
            .navigationTitle("Einstellungen")
        }
        .sheet(isPresented: $isPresentingProfileEditor) {
            SettingsProfileEditorSheet(
                name: $profileName,
                email: $profileEmail,
                favoriteStore: $favoriteStore,
                notificationsEnabled: $enableNotifications,
                isSaving: isSavingProfile,
                onDismiss: { isPresentingProfileEditor = false },
                onSave: saveProfileChanges
            )
            .environmentObject(settings)
        }
        .sheet(isPresented: $isPresentingShareSheet) {
            SettingsHouseholdShareSheet(
                householdName: settings.currentHousehold?.name,
                inviteEmail: $inviteEmail,
                onCancel: { isPresentingShareSheet = false },
                onSend: { isPresentingShareSheet = false }
            )
            .environmentObject(settings)
        }
        .sheet(isPresented: $isPresentingCreateHousehold) {
            SettingsCreateHouseholdSheet(
                title: "Haushalt erstellen",
                actionTitle: "Erstellen",
                householdName: $newHouseholdName,
                onCancel: { isPresentingCreateHousehold = false },
                onCreate: { name in
                    Task {
                        let created = await createHousehold(named: name)
                        if created {
                            isPresentingCreateHousehold = false
                        }
                    }
                }
            )
            .environmentObject(settings)
        }
        .sheet(isPresented: $isPresentingDeleteHousehold) {
            SettingsDeleteHouseholdSheet(
                households: settings.households,
                onDismiss: { isPresentingDeleteHousehold = false },
                onConfirmDeletion: { household in
                    householdPendingDeletion = household
                    isConfirmingHouseholdDeletion = true
                }
            )
            .environmentObject(settings)
        }
        .alert("Haushalt löschen", isPresented: $isConfirmingHouseholdDeletion, presenting: householdPendingDeletion) { household in
            Button("Löschen", role: .destructive) {
                Task {
                    await deleteHousehold(household)
                    isPresentingDeleteHousehold = false
                    householdPendingDeletion = nil
                }
            }
            Button("Abbrechen", role: .cancel) {
                householdPendingDeletion = nil
            }
        } message: { household in
            Text("Möchtest du \(household.name) wirklich löschen? Dieser Schritt kann nicht rückgängig gemacht werden.")
        }
        .task {
            await initializeProfile()
        }
        .onChange(of: settings.selectedHouseholdID) { _ in
            Task { await loadProfile() }
        }
    }
}

#Preview {
    SettingsScreen()
        .environmentObject(KorbiSettings())
        .environmentObject(AuthManager())
}

private extension SettingsScreen {
    func initializeProfile() async {
        await MainActor.run {
            profileEmail = authManager.currentUserEmail ?? profileEmail
        }
        await loadHouseholds()
        await loadProfile()
    }

    func loadHouseholds() async {
        do {
            let fetched = try await authManager.fetchHouseholds()
            await MainActor.run {
                settings.replaceHouseholds(fetched)
                householdActionError = nil
            }
        } catch {
            await MainActor.run {
                householdActionError = "Haushalte konnten nicht geladen werden."
            }
        }
    }

    func loadProfile() async {
        await MainActor.run {
            profileEmail = authManager.currentUserEmail ?? profileEmail
        }
        guard let household = settings.currentHousehold else {
            await MainActor.run {
                profileName = ""
            }
            return
        }

        do {
            if let membershipName = try await authManager.membershipName(for: household.id) {
                await MainActor.run {
                    profileName = membershipName
                    profileStatusMessage = nil
                }
            }
        } catch {
            await MainActor.run {
                profileStatusMessage = "Profilname konnte nicht geladen werden."
            }
        }
    }

    func saveProfileChanges() {
        guard let household = settings.currentHousehold else {
            profileStatusMessage = "Kein Haushalt ausgewählt."
            isPresentingProfileEditor = false
            return
        }

        let trimmedName = profileName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            profileStatusMessage = "Bitte gib einen Namen ein."
            return
        }

        isSavingProfile = true
        Task {
            do {
                try await authManager.updateMembershipName(trimmedName, for: household.id)
                await MainActor.run {
                    profileName = trimmedName
                    profileStatusMessage = "Profil aktualisiert."
                    isPresentingProfileEditor = false
                }
            } catch {
                await MainActor.run {
                    profileStatusMessage = "Profil konnte nicht aktualisiert werden."
                }
            }
            await MainActor.run {
                isSavingProfile = false
            }
        }
    }

    func createHousehold(named name: String) async -> Bool {
        do {
            if let household = try await authManager.createHousehold(named: name) {
                await MainActor.run {
                    settings.upsertHousehold(household)
                    householdActionError = nil
                }
                let trimmedName = profileName.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmedName.isEmpty {
                    try? await authManager.updateMembershipName(trimmedName, for: household.id)
                }
                await loadProfile()
                return true
            } else {
                await MainActor.run {
                    householdActionError = "Bitte gib einen gültigen Namen ein."
                }
                return false
            }
        } catch {
            await MainActor.run {
                householdActionError = "Haushalt konnte nicht erstellt werden."
            }
            return false
        }
    }

    func deleteHousehold(_ household: Household) async {
        do {
            try await authManager.deleteHousehold(household)
            await MainActor.run {
                settings.deleteHousehold(household)
                householdActionError = nil
            }
            await loadProfile()
        } catch {
            await MainActor.run {
                householdActionError = "Haushalt konnte nicht gelöscht werden."
            }
        }
    }
}

private struct SettingsProfileEditorSheet: View {
    @EnvironmentObject private var settings: KorbiSettings
    @Binding var name: String
    @Binding var email: String
    @Binding var favoriteStore: String
    @Binding var notificationsEnabled: Bool
    let isSaving: Bool
    let onDismiss: () -> Void
    let onSave: () -> Void

    private var isSaveDisabled: Bool {
        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving
    }

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
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Speichern", action: onSave)
                            .disabled(isSaveDisabled)
                    }
                }
            }
        }
    }
}

private struct SettingsHouseholdShareSheet: View {
    @EnvironmentObject private var settings: KorbiSettings
    let householdName: String?
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
                    Text("Lade weitere Personen zu \(displayHouseholdName) ein, damit ihr gemeinsam planen könnt.")
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

    private var displayHouseholdName: String {
        if let householdName, !householdName.isEmpty {
            return householdName
        }
        return "deinem Haushalt"
    }
}

struct SettingsCreateHouseholdSheet: View {
    let title: String
    let actionTitle: String
    @Binding var householdName: String
    let onCancel: () -> Void
    let onCreate: (String) -> Void

    private var isCreateDisabled: Bool {
        householdName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Name des Haushalts")) {
                    TextField("Familienname", text: $householdName)
                        .textInputAutocapitalization(.words)
                }
            }
            .scrollContentBackground(.hidden)
            .background(KorbiBackground())
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(actionTitle) {
                        let trimmed = householdName.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        onCreate(trimmed)
                    }
                    .disabled(isCreateDisabled)
                }
            }
        }
    }
}

struct SettingsDeleteHouseholdSheet: View {
    @EnvironmentObject private var settings: KorbiSettings
    let households: [Household]
    let onDismiss: () -> Void
    let onConfirmDeletion: (Household) -> Void
    @State private var selectedHousehold: Household? = nil
    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Haushalt auswählen")) {
                    ForEach(households) { household in
                        Button {
                            selectedHousehold = household
                        } label: {
                            HStack {
                                Text(household.name)
                                    .font(KorbiTheme.Typography.body(weight: .medium))
                                Spacer()
                                if selectedHousehold?.id == household.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(settings.palette.primary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                if households.isEmpty {
                    Text("Es sind keine Haushalte vorhanden.")
                        .font(KorbiTheme.Typography.body())
                        .foregroundStyle(settings.palette.textSecondary)
                        .padding(.vertical, 8)
                        .listRowBackground(Color.clear)
                }
            }
            .scrollContentBackground(.hidden)
            .background(KorbiBackground())
            .navigationTitle("Haushalt löschen")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen", action: onDismiss)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Löschen") {
                        guard let selectedHousehold else { return }
                        onConfirmDeletion(selectedHousehold)
                    }
                    .disabled(selectedHousehold == nil)
                }
            }
        }
        .onAppear {
            if selectedHousehold == nil {
                selectedHousehold = households.first
            }
        }
    }
}
