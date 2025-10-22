import Foundation

struct HouseholdEntity: Identifiable, Equatable, Hashable {
  let id: UUID
  var name: String
  var role: HouseholdRole
  var createdAt: Date
}

enum HouseholdRole: String, Codable, CaseIterable {
  case owner
  case admin
  case member

  var localizedTitle: String {
    switch self {
    case .owner:
      return "Inhaber:in"
    case .admin:
      return "Verwalter:in"
    case .member:
      return "Mitglied"
    }
  }
}

struct ListEntity: Identifiable, Equatable, Hashable {
  let id: UUID
  var householdID: UUID
  var name: String
  var isDefault: Bool
  var createdAt: Date
  var items: [ItemEntity]
}

struct HouseholdMemberEntity: Identifiable, Equatable, Hashable {
  let id: UUID
  var householdID: UUID
  var userID: UUID
  var displayName: String?
  var role: HouseholdRole
  var joinedAt: Date
}

enum ItemStatus: String, Codable, CaseIterable {
  case open
  case purchased
}

struct ItemEntity: Identifiable, Equatable, Hashable {
  let id: UUID
  var listID: UUID
  var name: String
  var quantityText: String?
  var quantityNumeric: Decimal?
  var unit: String?
  var status: ItemStatus
  var position: Int
  var createdAt: Date
  var purchasedAt: Date?
  var createdBy: UUID?
  var purchasedBy: UUID?

  var isOpen: Bool { status == .open }

  var formattedQuantity: String? {
    if let quantityText {
      return quantityText
    }
    if let quantityNumeric {
      let formatter = NumberFormatter()
      formatter.locale = Locale.current
      formatter.minimumFractionDigits = 0
      formatter.maximumFractionDigits = 2
      if let unit {
        return [formatter.string(for: quantityNumeric), unit]
          .compactMap { $0 }
          .joined(separator: " ")
      } else {
        return formatter.string(for: quantityNumeric)
      }
    }
    return unit
  }

  var detailDescription: String? {
    var parts: [String] = []
    if let unit, quantityText == nil, quantityNumeric == nil {
      parts.append(unit)
    }
    if status == .purchased, let purchasedAt {
      let formatter = RelativeDateTimeFormatter()
      formatter.locale = Locale.current
      parts.append("gekauft " + formatter.localizedString(for: purchasedAt, relativeTo: Date()))
    }
    return parts.isEmpty ? nil : parts.joined(separator: " · ")
  }

  var accessibilityLabel: String {
    var components: [String] = [name]
    if let formattedQuantity {
      components.append(formattedQuantity)
    }
    components.append(status == .purchased ? "erledigt" : "offen")
    return components.joined(separator: ", ")
  }
}

struct InviteEntity: Identifiable, Hashable {
  let id: UUID
  let token: UUID
  let url: URL
  let expiresAt: Date
  var householdName: String
  var createdByName: String?

  var formattedExpiry: String {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter.string(from: expiresAt)
  }
}

struct VoiceSessionState: Equatable {
  enum Phase: Equatable {
    case idle
    case recording(startedAt: Date)
    case uploading
    case success(transcript: String)
    case failure(errorMessage: String)
  }

  var phase: Phase = .idle
  var lastTranscript: String?
  var isProcessing: Bool {
    if case .uploading = phase { return true }
    return false
  }
}
