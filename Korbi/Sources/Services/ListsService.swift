import Foundation
import Supabase

protocol ListsServicing {
  func loadLists(for householdID: UUID) async throws
  func createList(name: String, householdID: UUID) async throws
  func renameList(_ listID: UUID, name: String) async throws
  func deleteList(_ listID: UUID) async throws
}

final class ListsService: ListsServicing {
  private let client: SupabaseClient
  private unowned let appState: AppState

  init(client: SupabaseClient, appState: AppState) {
    self.client = client
    self.appState = appState
  }

  func loadLists(for householdID: UUID) async throws {
    let response: PostgrestResponse<[ListRecord]> = try await client
      .from("lists")
      .select("id, household_id, name, is_default, created_at")
      .eq("household_id", value: householdID)
      .order("created_at", ascending: true)
      .execute()
    let lists = response.value.map { $0.entity }
    await MainActor.run {
      appState.lists = lists
    }
  }

  func createList(name: String, householdID: UUID) async throws {
    let insert = ListInsert(name: name, householdID: householdID)
    _ = try await client
      .from("lists")
      .insert(insert, returning: .minimal)
      .execute()
    try await loadLists(for: householdID)
  }

  func renameList(_ listID: UUID, name: String) async throws {
    _ = try await client
      .from("lists")
      .update(ListUpdate(name: name))
      .eq("id", value: listID)
      .execute()
    if let householdID = appState.lists.first(where: { $0.id == listID })?.householdID {
      try await loadLists(for: householdID)
    }
  }

  func deleteList(_ listID: UUID) async throws {
    _ = try await client
      .from("lists")
      .delete()
      .eq("id", value: listID)
      .execute()
    await MainActor.run {
      appState.lists.removeAll { $0.id == listID }
    }
  }
}

private struct ListRecord: Decodable {
  let id: UUID
  let householdID: UUID
  let name: String
  let isDefault: Bool
  let createdAt: Date

  enum CodingKeys: String, CodingKey {
    case id
    case householdID = "household_id"
    case name
    case isDefault = "is_default"
    case createdAt = "created_at"
  }

  var entity: ListEntity {
    ListEntity(
      id: id,
      householdID: householdID,
      name: name,
      isDefault: isDefault,
      createdAt: createdAt,
      items: []
    )
  }
}

private struct ListInsert: Encodable {
  let name: String
  let householdID: UUID

  enum CodingKeys: String, CodingKey {
    case name
    case householdID = "household_id"
  }
}

private struct ListUpdate: Encodable {
  let name: String
}
