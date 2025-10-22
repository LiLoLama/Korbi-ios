import Foundation
import Supabase

protocol RealtimeServicing: AnyObject {
  func subscribe(to householdID: UUID)
  func unsubscribe()
}

final class RealtimeService: RealtimeServicing {
  private let client: SupabaseClient
  private unowned let appState: AppState
  private var channel: RealtimeChannel?

  init(client: SupabaseClient, appState: AppState) {
    self.client = client
    self.appState = appState
  }

  func subscribe(to householdID: UUID) {
    unsubscribe()
    let channelName = "household:\(householdID.uuidString)"
    let channel = client.realtime.channel(.init(name: channelName))

    channel.on(.postgresChanges, filter: .init(event: .all, schema: "public", table: "items")) { [weak self] payload in
      self?.handleItemChange(payload: payload)
    }

    channel.on(.postgresChanges, filter: .init(event: .all, schema: "public", table: "lists")) { [weak self] payload in
      self?.handleListChange(payload: payload)
    }

    channel.subscribe()
    self.channel = channel
  }

  func unsubscribe() {
    if let channel {
      channel.unsubscribe()
    }
    channel = nil
  }

  private func handleListChange(payload: PostgresChangePayload) {
    guard let data: ListRecord = payload.decode() else { return }
    let entity = data.entity
    Task { @MainActor in
      if let index = appState.lists.firstIndex(where: { $0.id == entity.id }) {
        appState.lists[index] = entity
      } else {
        appState.lists.append(entity)
      }
    }
  }

  private func handleItemChange(payload: PostgresChangePayload) {
    Task { @MainActor in
      switch payload.eventType {
      case .insert, .update:
        if let record: ItemRecord = payload.decode() {
          let entity = record.entity
          var items = appState.items[entity.listID] ?? []
          if let idx = items.firstIndex(where: { $0.id == entity.id }) {
            items[idx] = entity
          } else {
            items.append(entity)
          }
          items.sort { lhs, rhs in
            if lhs.status == rhs.status {
              return lhs.createdAt > rhs.createdAt
            }
            return lhs.status == .open && rhs.status == .purchased
          }
          appState.items[entity.listID] = items
        }
      case .delete:
        if let record: ItemRecord = payload.decodeOld() {
          let entity = record.entity
          var items = appState.items[entity.listID] ?? []
          items.removeAll { $0.id == entity.id }
          appState.items[entity.listID] = items
        }
      default:
        break
      }
    }
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
    ListEntity(id: id, householdID: householdID, name: name, isDefault: isDefault, createdAt: createdAt, items: [])
  }
}
