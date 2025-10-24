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

    let voiceRecordingWebhookURL: URL

    init(
        households: [Household] = [],
        selectedHouseholdID: UUID? = nil,
        useWarmLightMode: Bool = false,
        recentPurchases: [String] = [],
        voiceRecordingWebhookURL: URL = URL(string: "https://korbi-webhook.example/api/voice")!
    ) {
        self.households = households
        self.selectedHouseholdID = selectedHouseholdID
        self.useWarmLightMode = useWarmLightMode
        self.recentPurchases = recentPurchases
        self.palette = useWarmLightMode ? .warmLight : .serene
        self.voiceRecordingWebhookURL = voiceRecordingWebhookURL

        ensureValidSelection()
    }

    func recordPurchase(_ item: String) {
        recentPurchases.insert(item, at: 0)
        if recentPurchases.count > 40 {
            recentPurchases.removeLast(recentPurchases.count - 40)
        }
    }

    func createHousehold(named name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let household = Household(name: trimmedName)
        households.append(household)
        selectedHouseholdID = household.id
    }

    func deleteHousehold(_ household: Household) {
        households.removeAll { $0.id == household.id }
        ensureValidSelection()
    }

    func selectHousehold(_ household: Household) {
        guard households.contains(household) else { return }
        selectedHouseholdID = household.id
    }

    var currentHousehold: Household? {
        guard !households.isEmpty else { return nil }
        if let selectedHouseholdID,
           let household = households.first(where: { $0.id == selectedHouseholdID }) {
            return household
        }
        return households.first
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
}
