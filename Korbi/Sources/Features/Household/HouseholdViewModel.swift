import Foundation
import Combine

@MainActor
final class HouseholdViewModel: ObservableObject {
  @Published private(set) var members: [HouseholdMemberEntity] = []
  @Published var invite: InviteEntity?
  @Published var errorMessage: String?

  private let appState: AppState
  private let householdService: HouseholdServicing

  init(appState: AppState, householdService: HouseholdServicing) {
    self.appState = appState
    self.householdService = householdService
  }

  func refresh() {
    guard let householdID = appState.activeHouseholdID else { return }
    Task {
      do {
        members = try await householdService.loadMembers(of: householdID)
        invite = nil
      } catch {
        errorMessage = error.localizedDescription
      }
    }
  }

  func join(tokenString: String) {
    guard let token = UUID(uuidString: tokenString) else {
      errorMessage = "Ungültiger Einladungslink"
      return
    }
    Task {
      do {
        try await householdService.joinHousehold(token: token)
        errorMessage = nil
      } catch {
        errorMessage = error.localizedDescription
      }
    }
  }

  func generateInvite() {
    guard let householdID = appState.activeHouseholdID else { return }
    Task {
      do {
        invite = try await householdService.generateInvite(for: householdID)
      } catch {
        errorMessage = error.localizedDescription
      }
    }
  }
}
