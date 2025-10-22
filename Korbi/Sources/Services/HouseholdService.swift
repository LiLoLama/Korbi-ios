import Foundation
import Supabase

protocol HouseholdServicing {
  func refreshHouseholds() async throws
  func createHousehold(name: String) async throws
  func joinHousehold(token: UUID) async throws
  func loadMembers(of householdID: UUID) async throws -> [HouseholdMemberEntity]
  func generateInvite(for householdID: UUID) async throws -> InviteEntity
}

final class HouseholdService: HouseholdServicing {
  private let client: SupabaseClient
  private unowned let appState: AppState

  init(client: SupabaseClient, appState: AppState) {
    self.client = client
    self.appState = appState
  }

  func refreshHouseholds() async throws {
    let response = try await client
      .from("household_members")
      .select("id, household_id, role, created_at, profiles:profiles!inner(display_name), households:households!inner(id, name, created_at)")
      .order("created_at", ascending: false)
      .execute()

    let records = try response.decoded(to: [HouseholdMembershipRecord].self)
    let households = records.map { record -> HouseholdEntity in
      HouseholdEntity(
        id: record.households.id,
        name: record.households.name,
        role: record.role,
        createdAt: record.households.createdAt
      )
    }

    await MainActor.run {
      appState.households = households
      if appState.activeHouseholdID == nil {
        appState.activeHouseholdID = households.first?.id
      }
    }
  }

  func createHousehold(name: String) async throws {
    let payload = HouseholdInsert(name: name)
    _ = try await client
      .from("households")
      .insert(payload, returning: .representation)
      .single()
      .execute()
    try await refreshHouseholds()
  }

  func joinHousehold(token: UUID) async throws {
    let payload = InviteRedeemPayload(token: token)
    _ = try await client.functions.invoke("redeem_invite", body: payload)
    try await refreshHouseholds()
  }

  func loadMembers(of householdID: UUID) async throws -> [HouseholdMemberEntity] {
    let response = try await client
      .from("household_members")
      .select("id, household_id, role, created_at, user_id, profiles:profiles(display_name)")
      .eq("household_id", value: householdID)
      .order("created_at", ascending: true)
      .execute()
    let records = try response.decoded(to: [HouseholdMembershipRecord].self)
    return records.map { $0.memberEntity }
  }

  func generateInvite(for householdID: UUID) async throws -> InviteEntity {
    struct Payload: Encodable { let household_id: UUID }
    let response: InviteRecord = try await client.functions.invoke("create_invite", body: Payload(household_id: householdID))
    guard let url = URL(string: "korbi://invite/\(response.token.uuidString)") else {
      throw URLError(.badURL)
    }
    return InviteEntity(
      id: UUID(),
      token: response.token,
      url: url,
      expiresAt: response.expiresAt,
      householdName: response.householdName,
      createdByName: response.createdByName
    )
  }
}

private struct HouseholdMembershipRecord: Decodable {
  let id: UUID
  let householdID: UUID
  let userID: UUID
  let role: HouseholdRole
  let createdAt: Date
  let profiles: ProfileRecord?
  let households: HouseholdRecord

  enum CodingKeys: String, CodingKey {
    case id
    case householdID = "household_id"
    case userID = "user_id"
    case role
    case createdAt = "created_at"
    case profiles
    case households
  }

  var memberEntity: HouseholdMemberEntity {
    HouseholdMemberEntity(
      id: id,
      householdID: householdID,
      userID: userID,
      displayName: profiles?.displayName,
      role: role,
      joinedAt: createdAt
    )
  }
}

private struct HouseholdRecord: Decodable {
  let id: UUID
  let name: String
  let createdAt: Date

  enum CodingKeys: String, CodingKey {
    case id
    case name
    case createdAt = "created_at"
  }
}

private struct ProfileRecord: Decodable {
  let displayName: String?

  enum CodingKeys: String, CodingKey {
    case displayName = "display_name"
  }
}

private struct HouseholdInsert: Encodable {
  let name: String
}

private struct InviteRedeemPayload: Encodable {
  let token: UUID
}

private struct InviteRecord: Decodable {
  let token: UUID
  let expiresAt: Date
  let householdName: String
  let createdByName: String?

  enum CodingKeys: String, CodingKey {
    case token
    case expiresAt = "expires_at"
    case householdName = "household_name"
    case createdByName = "created_by_name"
  }
}
