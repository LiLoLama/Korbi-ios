import Foundation
import Supabase

protocol RealtimeServicing: AnyObject {
  func subscribe(to householdID: UUID)
  func unsubscribe()
}

final class RealtimeService: RealtimeServicing {
  private let client: SupabaseClient
  private unowned let appState: AppState
  private var channel: RealtimeChannelV2?
  private var subscriptions: [RealtimeSubscription] = []
  private var subscriptionTask: Task<Void, Never>?
  private let decoderQueue = DispatchQueue(label: "RealtimeService.decoder")
  private let realtimeDecoder = AnyJSON.decoder

  init(client: SupabaseClient, appState: AppState) {
    self.client = client
    self.appState = appState
  }

  func subscribe(to householdID: UUID) {
    unsubscribe()
    let channelName = "household:\(householdID.uuidString)"
    let channel = client.realtimeV2.channel(channelName)

    let itemsSubscription = channel.onPostgresChange(AnyAction.self, schema: "public", table: "items") { [weak self] action in
      self?.handleItemChange(action: action)
    }

    let listsSubscription = channel.onPostgresChange(AnyAction.self, schema: "public", table: "lists") { [weak self] action in
      self?.handleListChange(action: action)
    }

    subscriptions = [itemsSubscription, listsSubscription]
    subscriptionTask = Task { await channel.subscribe() }
    self.channel = channel
  }

  func unsubscribe() {
    subscriptionTask?.cancel()
    subscriptionTask = nil
    subscriptions.forEach { $0.cancel() }
    subscriptions.removeAll()
    if let channel {
      Task { await channel.unsubscribe() }
    }
    channel = nil
  }

  private func handleListChange(action: AnyAction) {
    switch action {
    case .insert, .update:
      guard let data: ListRecord = decodeRecord(from: action) else { return }
      let entity = data.entity
      Task { @MainActor in
        if let index = appState.lists.firstIndex(where: { $0.id == entity.id }) {
          appState.lists[index] = entity
        } else {
          appState.lists.append(entity)
        }
      }
    case .delete:
      guard let data: ListRecord = decodeOldRecord(from: action) else { return }
      let entity = data.entity
      Task { @MainActor in
        appState.lists.removeAll { $0.id == entity.id }
      }
    }
  }

  private func handleItemChange(action: AnyAction) {
    switch action {
    case .insert, .update:
      guard let record: ItemRecord = decodeRecord(from: action) else { return }
      let entity = record.entity
      Task { @MainActor in
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
      guard let record: ItemRecord = decodeOldRecord(from: action) else { return }
      let entity = record.entity
      Task { @MainActor in
        var items = appState.items[entity.listID] ?? []
        items.removeAll { $0.id == entity.id }
        appState.items[entity.listID] = items
      }
    }
  }

  private func decodeRecord<T: Decodable>(from action: AnyAction) -> T? {
    decoderQueue.sync {
      switch action {
      case let .insert(insert):
        return try? insert.decodeRecord(as: T.self, decoder: realtimeDecoder)
      case let .update(update):
        return try? update.decodeRecord(as: T.self, decoder: realtimeDecoder)
      case .delete:
        return nil
      }
    }
  }

  private func decodeOldRecord<T: Decodable>(from action: AnyAction) -> T? {
    decoderQueue.sync {
      switch action {
      case let .update(update):
        return try? update.decodeOldRecord(as: T.self, decoder: realtimeDecoder)
      case let .delete(delete):
        return try? delete.decodeOldRecord(as: T.self, decoder: realtimeDecoder)
      case .insert:
        return nil
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
