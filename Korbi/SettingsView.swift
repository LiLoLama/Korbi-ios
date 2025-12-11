import SwiftUI
import UIKit
import PhotosUI

struct SettingsView: View {
    @EnvironmentObject private var settings: KorbiSettings
    @EnvironmentObject private var authManager: AuthManager
    @State private var isPresentingProfileEditor = false
    @State private var isPresentingShareSheet = false
    @State private var isPresentingCreateHousehold = false
    @State private var isPresentingDeleteHousehold = false
    @State private var isPresentingRenameHousehold = false
    @State private var profileName = ""
    @State private var profileEmail = "mia@example.com"
    @State private var favoriteStore = "Biomarkt am Platz"
    @State private var enableNotifications = true
    @State private var profileImageData: Data? = nil
    @State private var newHouseholdName = ""
    @State private var renameHouseholdName = ""
    @State private var householdPendingDeletion: Household? = nil
    @State private var isConfirmingHouseholdDeletion = false
    @State private var householdPendingLeave: Household? = nil
    @State private var isConfirmingHouseholdLeave = false

    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Profil").font(KorbiTheme.Typography.title())) {
                    if !settings.profileName.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Name")
                                .font(KorbiTheme.Typography.caption())
                                .foregroundStyle(settings.palette.textSecondary)
                            Text(settings.profileName)
                                .font(KorbiTheme.Typography.body(weight: .semibold))
                        }
                        .padding(.vertical, 4)
                    }
                    Button {
                        profileName = settings.profileName
                        profileEmail = authManager.currentUserEmail ?? profileEmail
                        profileImageData = settings.profileImageData
                        isPresentingProfileEditor = true
                    } label: {
                        Label("Profil bearbeiten", systemImage: "person.crop.circle")
                            .font(KorbiTheme.Typography.body(weight: .semibold))
                            .foregroundStyle(settings.palette.primary)
                    }
                }

                Section(header: Text("Haushalt").font(KorbiTheme.Typography.title())) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Aktueller Haushalt")
                            .font(KorbiTheme.Typography.body(weight: .semibold))
                            .foregroundStyle(settings.palette.textSecondary)

                        if let household = settings.currentHousehold {
                            Text(household.name)
                                .font(KorbiTheme.Typography.body())

                            Button {
                                renameHouseholdName = household.name
                                isPresentingRenameHousehold = true
                            } label: {
                                Label("Haushalt umbenennen", systemImage: "pencil")
                                    .font(KorbiTheme.Typography.body(weight: .semibold))
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(settings.palette.primary)
                            .disabled(!settings.canManageCurrentHousehold)
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
                    .disabled(settings.ownerHouseholds.isEmpty)

                    Button {
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
                    .disabled(!settings.canShareCurrentHousehold)
                }

                Section(header: Text("Beigetretene Haushalte").font(KorbiTheme.Typography.title())) {
                    if settings.viewerHouseholds.isEmpty {
                        Text("Du bist derzeit keinen Haushalten beigetreten.")
                            .font(KorbiTheme.Typography.body())
                            .foregroundStyle(settings.palette.textSecondary)
                            .padding(.vertical, 4)
                    } else {
                        ForEach(settings.viewerHouseholds) { household in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(household.name)
                                    .font(KorbiTheme.Typography.body(weight: .semibold))

                                Button {
                                    householdPendingLeave = household
                                    isConfirmingHouseholdLeave = true
                                } label: {
                                    Label("Haushalt verlassen", systemImage: "rectangle.portrait.and.arrow.right")
                                        .font(KorbiTheme.Typography.body(weight: .semibold))
                                }
                                .buttonStyle(.bordered)
                                .tint(.red)
                                .controlSize(.small)
                                .clipShape(RoundedRectangle(cornerRadius: KorbiTheme.Metrics.compactCornerRadius, style: .continuous))
                            }
                            .padding(.vertical, 4)
                        }
                    }
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
                profileImageData: $profileImageData,
                onDismiss: { isPresentingProfileEditor = false },
                onSave: {
                    settings.updateProfileName(to: profileName)
                    settings.updateProfileImage(with: profileImageData)
                    isPresentingProfileEditor = false
                }
            )
            .environmentObject(settings)
        }
        .sheet(isPresented: $isPresentingRenameHousehold) {
            RenameHouseholdSheet(
                householdName: $renameHouseholdName,
                onCancel: { isPresentingRenameHousehold = false },
                onRename: { name in
                    settings.updateCurrentHouseholdName(to: name)
                    isPresentingRenameHousehold = false
                }
            )
        }
        .sheet(isPresented: $isPresentingShareSheet) {
            HouseholdShareSheet(
                householdName: settings.currentHousehold?.name,
                householdID: settings.currentHousehold?.id,
                onDismiss: { isPresentingShareSheet = false }
            )
            .environmentObject(settings)
        }
        .sheet(isPresented: $isPresentingCreateHousehold) {
            CreateHouseholdSheet(
                title: "Haushalt erstellen",
                actionTitle: "Erstellen",
                householdName: $newHouseholdName,
                onCancel: { isPresentingCreateHousehold = false },
                onCreate: { name in
                    Task {
                        await settings.createHousehold(named: name)
                        await MainActor.run {
                            isPresentingCreateHousehold = false
                        }
                    }
                }
            )
            .environmentObject(settings)
        }
        .sheet(isPresented: $isPresentingDeleteHousehold) {
            DeleteHouseholdSheet(
                households: settings.ownerHouseholds,
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
                    await settings.deleteHousehold(household)
                    await MainActor.run {
                        isPresentingDeleteHousehold = false
                        householdPendingDeletion = nil
                    }
                }
            }
            Button("Abbrechen", role: .cancel) {
                householdPendingDeletion = nil
            }
        } message: { household in
            Text("Möchtest du \(household.name) wirklich löschen? Dieser Schritt kann nicht rückgängig gemacht werden.")
        }
        .alert("Haushalt verlassen", isPresented: $isConfirmingHouseholdLeave, presenting: householdPendingLeave) { household in
            Button("Verlassen", role: .destructive) {
                Task {
                    await settings.leaveHousehold(household)
                    await MainActor.run {
                        householdPendingLeave = nil
                    }
                }
            }
            Button("Abbrechen", role: .cancel) {
                householdPendingLeave = nil
            }
        } message: { household in
            Text("Möchtest du \(household.name) wirklich verlassen?")
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(KorbiSettings())
        .environmentObject(AuthManager())
}

private struct ProfileEditorSheet: View {
    @EnvironmentObject private var settings: KorbiSettings
    @Binding var name: String
    @Binding var email: String
    @Binding var favoriteStore: String
    @Binding var notificationsEnabled: Bool
    @Binding var profileImageData: Data?
    let onDismiss: () -> Void
    let onSave: () -> Void

    @State private var selectedPhoto: PhotosPickerItem? = nil

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Profil")) {
                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.words)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("E-Mail")
                            .font(KorbiTheme.Typography.caption())
                            .foregroundStyle(settings.palette.textSecondary)
                        Text(email)
                            .font(KorbiTheme.Typography.body())
                            .foregroundStyle(settings.palette.textPrimary)
                    }

                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        HStack {
                            if let profileImageData,
                               let uiImage = UIImage(data: profileImageData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 48, height: 48)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .accessibilityHidden(true)
                            } else {
                                Image(systemName: "person.crop.circle.fill")
                                    .font(.system(size: 32))
                                    .foregroundStyle(settings.palette.primary)
                                    .frame(width: 48, height: 48)
                                    .accessibilityHidden(true)
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Profilbild")
                                    .font(KorbiTheme.Typography.body(weight: .semibold))
                                Text("Lade ein Bild hoch, das in deinem Haushalt angezeigt wird.")
                                    .font(KorbiTheme.Typography.caption())
                                    .foregroundStyle(settings.palette.textSecondary)
                            }
                        }
                    }
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
                    Button("Abbrechen", action: onDismiss)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern", action: onSave)
                }
            }
            .onChange(of: selectedPhoto) { _, newValue in
                guard let newValue else { return }
                Task {
                    if let data = try? await newValue.loadTransferable(type: Data.self) {
                        await MainActor.run { profileImageData = data }
                    }
                }
            }
        }
    }
}

private struct RenameHouseholdSheet: View {
    @Binding var householdName: String
    let onCancel: () -> Void
    let onRename: (String) -> Void

    private var isRenameDisabled: Bool {
        householdName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Neuer Haushaltsname")) {
                    TextField("Haushaltsname", text: $householdName)
                        .textInputAutocapitalization(.words)
                }
            }
            .scrollContentBackground(.hidden)
            .background(KorbiBackground())
            .navigationTitle("Haushalt umbenennen")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        let trimmed = householdName.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        onRename(trimmed)
                    }
                    .disabled(isRenameDisabled)
                }
            }
        }
    }
}

private struct HouseholdShareSheet: View {
    @EnvironmentObject private var settings: KorbiSettings
    let householdName: String?
    let householdID: UUID?
    let onDismiss: () -> Void

    @State private var invite: HouseholdInvite? = nil
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var hintMessage: String? = nil

    private var displayHouseholdName: String {
        if let householdName, !householdName.isEmpty {
            return householdName
        }
        return "deinem Haushalt"
    }

    private var isActionDisabled: Bool {
        isLoading || invite == nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Einladungslink")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Teile den Link, damit weitere Personen \(displayHouseholdName) beitreten können.")
                            .font(KorbiTheme.Typography.body())
                            .foregroundStyle(settings.palette.textSecondary)

                        if let invite {
                            VStack(alignment: .leading, spacing: 12) {
                                Text(invite.linkURL.absoluteString)
                                    .font(KorbiTheme.Typography.caption())
                                    .textSelection(.enabled)

                                if let expiresAt = invite.expiresAt {
                                    Text("Gültig bis \(expiresAt.formatted(date: .abbreviated, time: .shortened))")
                                        .font(KorbiTheme.Typography.caption())
                                        .foregroundStyle(settings.palette.textSecondary)
                                }

                                actionButtons(for: invite)
                            }
                        }

                        if isLoading {
                            ProgressView("Wird geladen…")
                                .progressViewStyle(.circular)
                        }

                        if let errorMessage {
                            Text(errorMessage)
                                .font(KorbiTheme.Typography.caption(weight: .semibold))
                                .foregroundStyle(.red)
                        }

                        if let hintMessage {
                            Text(hintMessage)
                                .font(KorbiTheme.Typography.caption(weight: .semibold))
                                .foregroundStyle(settings.palette.primary)
                                .transition(.opacity)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    Button {
                        Task { await regenerateInvite() }
                    } label: {
                        Label("Neuen Link generieren", systemImage: "arrow.clockwise.circle")
                    }
                    .disabled(isLoading)

                    Button(role: .destructive) {
                        Task { await revokeInvite() }
                    } label: {
                        Label("Link widerrufen", systemImage: "xmark.circle")
                    }
                    .disabled(isActionDisabled)
                }
            }
            .scrollContentBackground(.hidden)
            .background(KorbiBackground())
            .navigationTitle("Haushalt teilen")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fertig", action: onDismiss)
                }
            }
            .task {
                await loadInviteIfNeeded()
            }
        }
    }

    @ViewBuilder
    private func actionButtons(for invite: HouseholdInvite) -> some View {
        VStack(spacing: 8) {
            Button {
                UIPasteboard.general.string = invite.linkURL.absoluteString
                showHint("Link kopiert")
            } label: {
                Label("In Zwischenablage kopieren", systemImage: "doc.on.doc")
                    .font(KorbiTheme.Typography.body(weight: .semibold))
            }

            ShareLink(item: invite.linkURL) {
                Label("Teilen", systemImage: "square.and.arrow.up")
                    .font(KorbiTheme.Typography.body(weight: .semibold))
            }
        }
    }

    private func loadInviteIfNeeded() async {
        guard let householdID else {
            errorMessage = InviteError.missingHousehold.errorDescription
            return
        }

        if let existing = settings.currentInvite(for: householdID) {
            invite = existing
            return
        }

        await regenerateInvite()
    }

    private func regenerateInvite() async {
        guard let householdID else {
            errorMessage = InviteError.missingHousehold.errorDescription
            return
        }

        await withLoading {
            do {
                let newInvite = try await settings.createInvite(for: householdID)
                invite = newInvite
                errorMessage = nil
                showHint("Neuer Link erstellt")
            } catch {
                invite = nil
                errorMessage = mapInviteError(error)
            }
        }
    }

    private func revokeInvite() async {
        guard let householdID else {
            errorMessage = InviteError.missingHousehold.errorDescription
            return
        }

        await withLoading {
            do {
                try await settings.revokeInvite(for: householdID)
                invite = nil
                showHint("Einladung widerrufen")
            } catch {
                errorMessage = mapInviteError(error)
            }
        }
    }

    private func withLoading(operation: @escaping () async -> Void) async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        await operation()
        await MainActor.run {
            isLoading = false
        }
    }

    private func mapInviteError(_ error: Error) -> String {
        if let inviteError = error as? InviteError {
            return inviteError.localizedDescription
        }
        if let supabaseError = error as? SupabaseError {
            return supabaseError.localizedDescription
        }
        return error.localizedDescription
    }

    private func showHint(_ message: String) {
        withAnimation(.easeInOut(duration: 0.2)) {
            hintMessage = message
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            withAnimation(.easeInOut(duration: 0.2)) {
                hintMessage = nil
            }
        }
    }
}

struct CreateHouseholdSheet: View {
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

struct DeleteHouseholdSheet: View {
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
                    Text("Du verwaltest derzeit keine Haushalte.")
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
