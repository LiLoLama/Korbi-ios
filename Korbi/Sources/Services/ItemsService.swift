import Foundation
import Supabase

protocol ItemsServicing {
  var realtimeService: RealtimeServicing? { get set }
  func loadItems(for listID: UUID) async throws
  func addItem(name: String, quantityText: String?, listID: UUID) async throws
  func updateItem(_ item: ItemEntity) async throws
  func deleteItem(id: UUID) async throws
  func togglePurchased(item: ItemEntity) async throws
}

final class ItemsService: ItemsServicing {
  private let client: SupabaseClient
  weak var realtimeService: RealtimeServicing?
  private unowned let appState: AppState

  init(client: SupabaseClient, realtimeService: RealtimeServicing?, appState: AppState) {
    self.client = client
    self.realtimeService = realtimeService
    self.appState = appState
  }

  func loadItems(for listID: UUID) async throws {
    let response: PostgrestResponse<[ItemRecord]> = try await client
      .from("items")
      .select("id, list_id, name, quantity_text, quantity_numeric, unit, status, position, created_at, purchased_at, created_by, purchased_by")
      .eq("list_id", value: listID)
      .order("status", ascending: true)
      .order("created_at", ascending: false)
      .execute()
    let entities = response.value.map { $0.entity }
    await MainActor.run {
      appState.items[listID] = entities
    }
  }

  func addItem(name: String, quantityText: String?, listID: UUID) async throws {
    let insert = ItemInsert(listID: listID, name: name, quantityText: quantityText)
    _ = try await client
      .from("items")
      .insert(insert, returning: .representation)
      .single()
      .execute()
  }

  func updateItem(_ item: ItemEntity) async throws {
    let update = ItemUpdate(name: item.name, quantityText: item.quantityText, unit: item.unit, status: item.status)
    _ = try await client
      .from("items")
      .update(update)
      .eq("id", value: item.id)
      .execute()
  }

  func deleteItem(id: UUID) async throws {
    _ = try await client
      .from("items")
      .delete()
      .eq("id", value: id)
      .execute()
  }

  func togglePurchased(item: ItemEntity) async throws {
    let newStatus: ItemStatus = item.status == .open ? .purchased : .open
    let update = ItemUpdate(name: item.name, quantityText: item.quantityText, unit: item.unit, status: newStatus)
    _ = try await client
      .from("items")
      .update(update)
      .eq("id", value: item.id)
      .execute()
  }
}

private struct ItemRecord: Decodable {
  let id: UUID
  let listID: UUID
  let name: String
  let quantityText: String?
  let quantityNumeric: Decimal?
  let unit: String?
  let status: ItemStatus
  let position: Int
  let createdAt: Date
  let purchasedAt: Date?
  let createdBy: UUID?
  let purchasedBy: UUID?

  enum CodingKeys: String, CodingKey {
    case id
    case listID = "list_id"
    case name
    case quantityText = "quantity_text"
    case quantityNumeric = "quantity_numeric"
    case unit
    case status
    case position
    case createdAt = "created_at"
    case purchasedAt = "purchased_at"
    case createdBy = "created_by"
    case purchasedBy = "purchased_by"
  }

  var entity: ItemEntity {
    ItemEntity(
      id: id,
      listID: listID,
      name: name,
      quantityText: quantityText,
      quantityNumeric: quantityNumeric,
      unit: unit,
      status: status,
      position: position,
      createdAt: createdAt,
      purchasedAt: purchasedAt,
      createdBy: createdBy,
      purchasedBy: purchasedBy
    )
  }
}

private struct ItemInsert: Encodable {
  let listID: UUID
  let name: String
  let quantityText: String?

  enum CodingKeys: String, CodingKey {
    case listID = "list_id"
    case name
    case quantityText = "quantity_text"
  }
}

private struct ItemUpdate: Encodable {
  let name: String
  let quantityText: String?
  let unit: String?
  let status: ItemStatus

  enum CodingKeys: String, CodingKey {
    case name
    case quantityText = "quantity_text"
    case unit
    case status
  }
}
