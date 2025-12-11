import SwiftUI
import Foundation

struct KorbiColorPalette {
    let primary: Color
    let background: Color
    let card: Color
    let accent: Color
    let outline: Color
    let textPrimary: Color
    let textSecondary: Color

    static let serene = KorbiColorPalette(
        primary: Color("PrimaryGreen"),
        background: Color("NeutralBackground"),
        card: Color("NeutralCard"),
        accent: Color("AccentSand"),
        outline: Color("OutlineMist"),
        textPrimary: Color.primary,
        textSecondary: Color.primary.opacity(0.6)
    )

    static let warmLight = KorbiColorPalette(
        primary: Color(red: 0.78, green: 0.45, blue: 0.29),
        background: Color(red: 0.99, green: 0.96, blue: 0.91),
        card: Color(red: 1.0, green: 0.98, blue: 0.94),
        accent: Color(red: 0.95, green: 0.78, blue: 0.55),
        outline: Color(red: 0.91, green: 0.79, blue: 0.64),
        textPrimary: Color(red: 0.31, green: 0.21, blue: 0.17),
        textSecondary: Color(red: 0.45, green: 0.33, blue: 0.27).opacity(0.75)
    )
}

struct Household: Identifiable, Equatable {
    let id: UUID
    var name: String

    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }
}

struct HouseholdMemberProfile: Identifiable, Equatable {
    let id: String
    let userID: UUID
    let name: String
    let role: String?
    let status: String?
    let email: String?
    let avatarData: Data?
}

struct HouseholdItem: Identifiable, Equatable {
    let id: UUID
    let name: String
    let description: String
    let quantity: String
    let category: String
}

struct HouseholdInvite: Identifiable, Equatable {
    let id: UUID
    let token: String
    let expiresAt: Date?

    var linkURL: URL {
        URL(string: "https://liamschmid.com/korbiinvite?token=\(token)")!
    }
}

enum InviteError: LocalizedError {
    case missingHousehold
    case notAuthenticated
    case insufficientPermissions

    var errorDescription: String? {
        switch self {
        case .missingHousehold:
            return "Kein Haushalt ausgewählt."
        case .notAuthenticated:
            return "Bitte melde dich an, um Einladungen zu verwalten."
        case .insufficientPermissions:
            return "Dir fehlen die Berechtigungen, um Einladungen zu verwalten."
        }
    }
}

@MainActor
final class KorbiSettings: ObservableObject {
    private enum StorageKey {
        static let warmLightMode = "korbi.useWarmLightMode"
        static let profileImage = "korbi.profileImage.data"
    }

    @Published private(set) var households: [Household]
    @Published private(set) var selectedHouseholdID: UUID?
    @Published var useWarmLightMode: Bool {
        didSet {
            updatePalette()
            userDefaults.set(useWarmLightMode, forKey: StorageKey.warmLightMode)
        }
    }
    @Published private(set) var recentPurchases: [String]
    @Published private(set) var palette: KorbiColorPalette
    @Published private(set) var householdMembers: [UUID: [HouseholdMemberProfile]]
    @Published private(set) var householdItems: [UUID: [HouseholdItem]]
    @Published private(set) var householdInvites: [UUID: HouseholdInvite]
    @Published private(set) var householdRoles: [UUID: String]
    @Published private(set) var profileName: String
    @Published private(set) var profileImageData: Data? {
        didSet {
            userDefaults.set(profileImageData, forKey: StorageKey.profileImage)
            propagateProfileImage()
        }
    }
    @Published private(set) var currentUserID: UUID?

    let voiceRecordingWebhookURL: URL

    private let supabaseClient: SupabaseService
    private weak var authManager: AuthManager?
    private var activeSession: SupabaseAuthSession?
    private let userDefaults: UserDefaults

    init(
        households: [Household] = [],
        selectedHouseholdID: UUID? = nil,
        useWarmLightMode: Bool = false,
        recentPurchases: [String] = [],
        voiceRecordingWebhookURL: URL? = nil,
        supabaseClient: SupabaseService = SupabaseClient(),
        bundle: Bundle = .main,
        userDefaults: UserDefaults = .standard
    ) {
        self.households = households
        self.selectedHouseholdID = selectedHouseholdID
        self.userDefaults = userDefaults
        let storedTheme = userDefaults.object(forKey: StorageKey.warmLightMode) as? Bool
        self.useWarmLightMode = storedTheme ?? useWarmLightMode
        self.recentPurchases = recentPurchases
        self.palette = self.useWarmLightMode ? .warmLight : .serene
        self.voiceRecordingWebhookURL = voiceRecordingWebhookURL ?? KorbiSettings.resolveVoiceRecordingWebhook(from: bundle)
        self.supabaseClient = supabaseClient
        self.householdMembers = [:]
        self.householdItems = [:]
        self.householdInvites = [:]
        self.householdRoles = [:]
        self.profileName = ""
        self.profileImageData = userDefaults.data(forKey: StorageKey.profileImage)

        ensureValidSelection()
    }

    func configure(authManager: AuthManager) {
        self.authManager = authManager
        if profileName.isEmpty, let email = authManager.currentUserEmail {
            profileName = email
        }
    }

    private static func resolveVoiceRecordingWebhook(from bundle: Bundle) -> URL {
        if let urlString = bundle.object(forInfoDictionaryKey: "VOICE_RECORDING_WEBHOOK_URL") as? String,
           let url = URL(string: urlString) {
            return url
        }

        #if DEBUG
        print("Missing VOICE_RECORDING_WEBHOOK_URL entry in Info.plist – falling back to placeholder URL.")
        #endif

        return URL(string: "https://korbi-webhook.example/api/voice")!
    }

    func recordPurchase(_ item: String) {
        recentPurchases.insert(item, at: 0)
        if recentPurchases.count > 40 {
            recentPurchases.removeLast(recentPurchases.count - 40)
        }
    }

    func markItemAsPurchased(_ item: HouseholdItem) async {
        guard let householdID = selectedHouseholdID else { return }

        var didRemoveItem = false

        withAnimation(.easeInOut(duration: 0.25)) {
            var items = householdItems[householdID] ?? []
            if let index = items.firstIndex(of: item) {
                items.remove(at: index)
                householdItems[householdID] = items
                recordPurchase(item.name)
                didRemoveItem = true
            }
        }

        guard didRemoveItem, let authManager else { return }

        do {
            let session = try await authManager.getValidSession()
            activeSession = session
            try await supabaseClient.deleteItem(id: item.id, accessToken: session.accessToken)
        } catch {
            #if DEBUG
            print("Failed to delete item from Supabase: \(error)")
            #endif
        }
    }

    func refreshActiveSession() async {
        guard let authManager else { return }

        do {
            let session = try await authManager.getValidSession()
            await refreshData(with: session)
        } catch {
            #if DEBUG
            print("Failed to refresh active session: \(error)")
            #endif
        }
    }

    func refreshData(with session: SupabaseAuthSession) async {
        activeSession = session
        currentUserID = session.userID
        do {
            let remoteHouseholds = try await supabaseClient.fetchHouseholds(accessToken: session.accessToken)
            let mappedHouseholds = remoteHouseholds.map { Household(id: $0.id, name: $0.name) }
            households = mappedHouseholds
            let memberships = try await supabaseClient.fetchMemberships(userID: session.userID, accessToken: session.accessToken)
            let roles = memberships.reduce(into: [UUID: String]()) { partialResult, membership in
                if let role = membership.role?.lowercased() {
                    partialResult[membership.householdID] = role
                }
            }
            householdRoles = roles
            ensureValidSelection()
            let validIDs = Set(mappedHouseholds.map { $0.id })
            householdMembers = householdMembers.filter { validIDs.contains($0.key) }
            householdItems = householdItems.filter { validIDs.contains($0.key) }

            if let currentID = currentHousehold?.id {
                await updateMembersAndProfile(for: currentID, session: session)
                await updateItems(for: currentID, session: session)
            }
        } catch {
            #if DEBUG
            print("Failed to refresh Supabase data: \(error)")
            #endif
        }
    }

    func createHousehold(named name: String) async {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        guard let authManager else {
            #if DEBUG
            print("Cannot create household without an auth manager")
            #endif
            return
        }

        let newID = UUID()
        do {
            let session = try await authManager.getValidSession()
            activeSession = session
            try await supabaseClient.createHousehold(id: newID, name: trimmedName, accessToken: session.accessToken)
            await refreshData(with: session)
            selectedHouseholdID = newID
        } catch {
            #if DEBUG
            print("Failed to create household: \(error)")
            #endif
        }
    }

    func deleteHousehold(_ household: Household) async {
        guard let authManager else {
            #if DEBUG
            print("Cannot delete household without an auth manager")
            #endif
            return
        }

        do {
            let session = try await authManager.getValidSession()
            activeSession = session
            try await supabaseClient.deleteHousehold(id: household.id, accessToken: session.accessToken)
            await refreshData(with: session)
        } catch {
            #if DEBUG
            print("Failed to delete household: \(error)")
            #endif
        }
    }

    func selectHousehold(_ household: Household) {
        guard households.contains(household) else { return }
        selectedHouseholdID = household.id
        guard let authManager else { return }

        Task { @MainActor in
            do {
                let session = try await authManager.getValidSession()
                activeSession = session
                await updateMembersAndProfile(for: household.id, session: session)
                await updateItems(for: household.id, session: session)
            } catch {
                #if DEBUG
                print("Failed to load data for selected household: \(error)")
                #endif
            }
        }
    }

    func updateProfileName(to name: String) {
        guard let householdID = selectedHouseholdID else { return }

        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        Task {
            do {
                guard let authManager else { return }
                let session = try await authManager.getValidSession()
                activeSession = session
                try await supabaseClient.updateHouseholdMemberName(
                    userID: session.userID,
                    householdID: householdID,
                    name: trimmed,
                    accessToken: session.accessToken
                )
                await MainActor.run {
                    profileName = trimmed
                    currentUserID = session.userID
                    var members = householdMembers[householdID] ?? []
                    syncMemberProfile(
                        for: session.userID,
                        householdID: householdID,
                        name: trimmed,
                        role: nil,
                        status: nil,
                        email: session.email,
                        avatarData: profileImageData,
                        existingMembers: &members
                    )
                    householdMembers[householdID] = members
                }
            } catch {
                #if DEBUG
                print("Failed to update profile name: \(error)")
                #endif
            }
        }
    }

    func updateCurrentHouseholdName(to name: String) {
        guard let householdID = selectedHouseholdID else { return }
        guard role(for: householdID) == "owner" else { return }

        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        Task {
            do {
                guard let authManager else { return }
                let session = try await authManager.getValidSession()
                activeSession = session
                try await supabaseClient.updateHouseholdName(
                    id: householdID,
                    name: trimmed,
                    accessToken: session.accessToken
                )

                await MainActor.run {
                    if let index = households.firstIndex(where: { $0.id == householdID }) {
                        households[index].name = trimmed
                    }
                }
            } catch {
                #if DEBUG
                print("Failed to rename household: \(error)")
                #endif
            }
        }
    }

    func currentInvite(for householdID: UUID) -> HouseholdInvite? {
        householdInvites[householdID]
    }

    @discardableResult
    func createInvite(
        for householdID: UUID,
        email: String? = nil,
        role: InviteRole = .viewer,
        ttlHours: Int = 168
    ) async throws -> HouseholdInvite {
        guard let authManager else { throw InviteError.notAuthenticated }
        guard self.role(for: householdID) == "owner" else { throw InviteError.insufficientPermissions }

        do {
            let session = try await authManager.getValidSession()
            activeSession = session
            let response = try await supabaseClient.createInvite(
                householdID: householdID,
                email: email,
                role: role,
                ttlHours: ttlHours,
                accessToken: session.accessToken
            )
            let invite = HouseholdInvite(id: response.id, token: response.token, expiresAt: response.expiresAt)
            householdInvites[householdID] = invite
            return invite
        } catch {
            throw error
        }
    }

    func revokeInvite(for householdID: UUID) async throws {
        guard let authManager else { throw InviteError.notAuthenticated }
        guard let invite = householdInvites[householdID] else { return }
        guard role(for: householdID) == "owner" else { throw InviteError.insufficientPermissions }

        do {
            let session = try await authManager.getValidSession()
            activeSession = session
            try await supabaseClient.revokeInvite(inviteID: invite.id, accessToken: session.accessToken)
            householdInvites[householdID] = nil
        } catch {
            throw error
        }
    }

    @discardableResult
    func acceptInvite(token: String) async throws -> Household? {
        guard let authManager else { throw InviteError.notAuthenticated }

        do {
            let session = try await authManager.getValidSession()
            activeSession = session
            let acceptance = try await supabaseClient.acceptInvite(token: token, accessToken: session.accessToken)
            await refreshData(with: session)
            let household = households.first(where: { $0.id == acceptance.householdID }) ?? Household(
                id: acceptance.householdID,
                name: acceptance.householdName ?? "Haushalt"
            )
            selectedHouseholdID = household.id
            Task {
                await notifyMemberJoined(household: household, session: session)
            }
            return household
        } catch {
            throw error
        }
    }

    func leaveHousehold(_ household: Household) async {
        guard let authManager else {
            #if DEBUG
            print("Cannot leave household without an auth manager")
            #endif
            return
        }

        do {
            let session = try await authManager.getValidSession()
            activeSession = session
            try await supabaseClient.leaveHousehold(
                householdID: household.id,
                userID: session.userID,
                accessToken: session.accessToken
            )
            await refreshData(with: session)
            if selectedHouseholdID == household.id {
                ensureValidSelection()
            }
        } catch {
            #if DEBUG
            print("Failed to leave household: \(error)")
            #endif
        }
    }

    func removeMember(_ member: HouseholdMemberProfile, from household: Household) async {
        guard role(for: household.id) == "owner" else { return }

        do {
            guard let authManager else { return }
            let session = try await authManager.getValidSession()
            activeSession = session
            try await supabaseClient.removeMember(
                householdID: household.id,
                userID: member.userID,
                accessToken: session.accessToken
            )
            await MainActor.run {
                var members = householdMembers[household.id] ?? []
                members.removeAll { $0.id == member.id }
                householdMembers[household.id] = members
            }
        } catch {
            #if DEBUG
            print("Failed to remove member: \(error)")
            #endif
        }
    }

    var currentHousehold: Household? {
        guard !households.isEmpty else { return nil }
        if let selectedHouseholdID,
           let household = households.first(where: { $0.id == selectedHouseholdID }) {
            return household
        }
        return households.first
    }

    func role(for householdID: UUID) -> String? {
        householdRoles[householdID]
    }

    var currentHouseholdRole: String? {
        guard let householdID = currentHousehold?.id else { return nil }
        return role(for: householdID)
    }

    var ownerHouseholds: [Household] {
        households.filter { role(for: $0.id) == "owner" }
    }

    var viewerHouseholds: [Household] {
        households.filter { role(for: $0.id) == "viewer" }
    }

    var canManageCurrentHousehold: Bool {
        currentHouseholdRole == "owner"
    }

    var canShareCurrentHousehold: Bool {
        canManageCurrentHousehold
    }

    var currentHouseholdMembers: [HouseholdMemberProfile] {
        guard let householdID = currentHousehold?.id else { return [] }
        return householdMembers[householdID] ?? []
    }

    var currentHouseholdItems: [HouseholdItem] {
        guard let householdID = currentHousehold?.id else { return [] }
        return householdItems[householdID] ?? []
    }

    func items(for category: String) -> [HouseholdItem] {
        currentHouseholdItems.filter { item in
            item.category.compare(category, options: .caseInsensitive) == .orderedSame
        }
    }

    private func updatePalette() {
        withAnimation(.easeInOut(duration: 0.25)) {
            palette = useWarmLightMode ? .warmLight : .serene
        }
    }

    private func ensureValidSelection() {
        if households.isEmpty {
            selectedHouseholdID = nil
        } else if let selectedHouseholdID,
                  households.contains(where: { $0.id == selectedHouseholdID }) {
            return
        } else {
            selectedHouseholdID = households.first?.id
        }
    }

    var backgroundGradient: [Color] {
        if useWarmLightMode {
            return [
                palette.background,
                palette.background.opacity(0.92)
            ]
        } else {
            return [
                palette.background.opacity(1.0),
                palette.background.opacity(0.92)
            ]
        }
    }

    private func updateMembersAndProfile(for householdID: UUID, session: SupabaseAuthSession) async {
        do {
            let members = try await supabaseClient.fetchHouseholdMembers(householdID: householdID, accessToken: session.accessToken)
            let mapped = members.map { member in
                HouseholdMemberProfile(
                    id: member.id,
                    userID: member.userID,
                    name: member.name ?? member.email ?? "Mitglied",
                    role: member.role,
                    status: member.status,
                    email: member.email,
                    avatarData: member.userID == session.userID ? profileImageData : nil
                )
            }
            await MainActor.run {
                householdMembers[householdID] = mapped
                if let currentMember = members.first(where: { $0.userID == session.userID }) {
                    currentUserID = session.userID
                    let fallbackName = profileName.isEmpty ? session.email : profileName
                    profileName = currentMember.name ?? fallbackName
                }
            }
        } catch {
            #if DEBUG
            print("Failed to fetch household members: \(error)")
            #endif
        }
    }

    func updateProfileImage(with data: Data?) {
        profileImageData = data
    }

    private func updateItems(for householdID: UUID, session: SupabaseAuthSession) async {
        do {
            let items = try await supabaseClient.fetchItems(accessToken: session.accessToken, householdID: householdID)
            let mapped = items.map { item in
                HouseholdItem(
                    id: item.id,
                    name: item.name,
                    description: item.description ?? "",
                    quantity: item.quantity ?? "",
                    category: item.category ?? "Sonstiges"
                )
            }
            let previousItems = householdItems[householdID] ?? []
            let existingIDs = Set(previousItems.map(\.id))
            let currentIDs = Set(mapped.map(\.id))
            let addedItems = currentIDs.subtracting(existingIDs)
            await MainActor.run {
                householdItems[householdID] = mapped
            }
            if !addedItems.isEmpty,
               let household = households.first(where: { $0.id == householdID }) {
                Task {
                    await notifyHouseholdAboutNewItems(in: household, session: session)
                }
            }
        } catch {
            #if DEBUG
            print("Failed to fetch items: \(error)")
            #endif
        }
    }

    private func notifyHouseholdAboutNewItems(in household: Household, session: SupabaseAuthSession) async {
        let message = "Es wurden neue Artikel zu \(household.name) hinzugefügt"
        do {
            try await supabaseClient.sendHouseholdNotification(
                message: message,
                householdID: household.id,
                accessToken: session.accessToken
            )
        } catch {
            #if DEBUG
            print("Failed to send new items notification: \(error)")
            #endif
        }
    }

    private func notifyMemberJoined(household: Household, session: SupabaseAuthSession) async {
        let trimmedName = profileName.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName: String
        if !trimmedName.isEmpty, trimmedName.lowercased() != "du" {
            displayName = trimmedName
        } else if !session.email.isEmpty {
            displayName = session.email
        } else {
            displayName = "Ein Mitglied"
        }

        let message = "\(displayName) ist dem Haushalt \(household.name) beigetreten"
        do {
            try await supabaseClient.sendHouseholdNotification(
                message: message,
                householdID: household.id,
                accessToken: session.accessToken
            )
        } catch {
            #if DEBUG
            print("Failed to send member joined notification: \(error)")
            #endif
        }
    }

    private func propagateProfileImage() {
        guard let userID = currentUserID else { return }
        householdMembers.keys.forEach { householdID in
            var members = householdMembers[householdID] ?? []
            syncMemberProfile(
                for: userID,
                householdID: householdID,
                name: nil,
                role: nil,
                status: nil,
                email: nil,
                avatarData: profileImageData,
                existingMembers: &members
            )
            householdMembers[householdID] = members
        }
    }

    private func syncMemberProfile(
        for userID: UUID,
        householdID: UUID,
        name: String?,
        role: String?,
        status: String?,
        email: String?,
        avatarData: Data?,
        existingMembers: inout [HouseholdMemberProfile]
    ) {
        let memberID = "\(householdID.uuidString)-\(userID.uuidString)"
        if let index = existingMembers.firstIndex(where: { $0.id == memberID }) {
            let existing = existingMembers[index]
            existingMembers[index] = HouseholdMemberProfile(
                id: existing.id,
                userID: userID,
                name: name ?? existing.name,
                role: role ?? existing.role,
                status: status ?? existing.status,
                email: email ?? existing.email,
                avatarData: avatarData ?? existing.avatarData
            )
        } else {
            existingMembers.append(
                HouseholdMemberProfile(
                    id: memberID,
                    userID: userID,
                    name: name ?? "Mitglied",
                    role: role,
                    status: status,
                    email: email,
                    avatarData: avatarData
                )
            )
        }
    }
}
