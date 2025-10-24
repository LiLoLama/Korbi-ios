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
    let name: String
    let role: String?
    let status: String?
}

struct HouseholdItem: Identifiable, Equatable {
    let id: UUID
    let name: String
    let description: String
    let quantity: String
    let category: String
}

@MainActor
final class KorbiSettings: ObservableObject {
    @Published private(set) var households: [Household]
    @Published private(set) var selectedHouseholdID: UUID?
    @Published var useWarmLightMode: Bool {
        didSet {
            updatePalette()
        }
    }
    @Published private(set) var recentPurchases: [String]
    @Published private(set) var palette: KorbiColorPalette
    @Published private(set) var householdMembers: [UUID: [HouseholdMemberProfile]]
    @Published private(set) var householdItems: [UUID: [HouseholdItem]]
    @Published private(set) var profileName: String

    let voiceRecordingWebhookURL: URL

    private let supabaseClient: SupabaseService
    private var activeSession: SupabaseAuthSession?

    init(
        households: [Household] = [],
        selectedHouseholdID: UUID? = nil,
        useWarmLightMode: Bool = false,
        recentPurchases: [String] = [],
        voiceRecordingWebhookURL: URL = URL(string: "https://korbi-webhook.example/api/voice")!,
        supabaseClient: SupabaseService = SupabaseClient()
    ) {
        self.households = households
        self.selectedHouseholdID = selectedHouseholdID
        self.useWarmLightMode = useWarmLightMode
        self.recentPurchases = recentPurchases
        self.palette = useWarmLightMode ? .warmLight : .serene
        self.voiceRecordingWebhookURL = voiceRecordingWebhookURL
        self.supabaseClient = supabaseClient
        self.householdMembers = [:]
        self.householdItems = [:]
        self.profileName = ""

        ensureValidSelection()
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

        guard didRemoveItem, let session = activeSession else { return }

        do {
            try await supabaseClient.deleteItem(id: item.id, accessToken: session.accessToken)
        } catch {
            #if DEBUG
            print("Failed to delete item from Supabase: \(error)")
            #endif
        }
    }

    func refreshActiveSession() async {
        guard let session = activeSession else { return }
        await refreshData(with: session)
    }

    func refreshData(with session: SupabaseAuthSession) async {
        activeSession = session
        do {
            let remoteHouseholds = try await supabaseClient.fetchHouseholds(accessToken: session.accessToken)
            let mappedHouseholds = remoteHouseholds.map { Household(id: $0.id, name: $0.name) }
            households = mappedHouseholds
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

        guard let session = activeSession else {
            #if DEBUG
            print("Cannot create household without an active session")
            #endif
            return
        }

        let newID = UUID()
        do {
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
        guard let session = activeSession else {
            #if DEBUG
            print("Cannot delete household without an active session")
            #endif
            return
        }

        do {
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
        guard let session = activeSession else { return }
        Task {
            await updateMembersAndProfile(for: household.id, session: session)
            await updateItems(for: household.id, session: session)
        }
    }

    func updateProfileName(to name: String) {
        guard let session = activeSession,
              let householdID = selectedHouseholdID else { return }

        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        Task {
            do {
                try await supabaseClient.updateHouseholdMemberName(
                    userID: session.userID,
                    householdID: householdID,
                    name: trimmed,
                    accessToken: session.accessToken
                )
                await MainActor.run {
                    profileName = trimmed
                    var members = householdMembers[householdID] ?? []
                    let memberID = "\(householdID.uuidString)-\(session.userID.uuidString)"
                    if let index = members.firstIndex(where: { $0.id == memberID }) {
                        members[index] = HouseholdMemberProfile(
                            id: members[index].id,
                            name: trimmed,
                            role: members[index].role,
                            status: members[index].status
                        )
                    } else {
                        members.append(
                            HouseholdMemberProfile(
                                id: memberID,
                                name: trimmed,
                                role: nil,
                                status: nil
                            )
                        )
                    }
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
        guard let session = activeSession,
              let householdID = selectedHouseholdID else { return }

        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        Task {
            do {
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

    var currentHousehold: Household? {
        guard !households.isEmpty else { return nil }
        if let selectedHouseholdID,
           let household = households.first(where: { $0.id == selectedHouseholdID }) {
            return household
        }
        return households.first
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
                    name: member.name ?? "Mitglied",
                    role: member.role,
                    status: member.status
                )
            }
            await MainActor.run {
                householdMembers[householdID] = mapped
                if let currentMember = members.first(where: { $0.userID == session.userID }) {
                    profileName = currentMember.name ?? profileName
                }
            }
        } catch {
            #if DEBUG
            print("Failed to fetch household members: \(error)")
            #endif
        }
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
            await MainActor.run {
                householdItems[householdID] = mapped
            }
        } catch {
            #if DEBUG
            print("Failed to fetch items: \(error)")
            #endif
        }
    }
}
