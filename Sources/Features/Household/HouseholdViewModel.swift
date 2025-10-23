import Foundation
import SwiftUI

@MainActor
final class HouseholdViewModel: ObservableObject {
    @Published var household: Household?
    @Published var members: [HouseholdMember] = []
    @Published var bannerState: BannerState = .idle

    private let service: HouseholdServicing

    init(service: HouseholdServicing) {
        self.service = service
    }

    func onAppear() {
        Task {
            await load()
        }
    }

    func load() async {
        do {
            async let householdValue = service.fetchHousehold()
            async let membersValue = service.fetchMembers()
            household = try await householdValue
            members = try await membersValue
        } catch {
            bannerState = .error(message: error.localizedDescription)
        }
    }
}
