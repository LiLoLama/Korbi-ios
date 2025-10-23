import Foundation

struct Household: Identifiable, Equatable, Hashable {
    let id: UUID
    var name: String
    var members: [HouseholdMember]
}

struct HouseholdMember: Identifiable, Equatable, Hashable {
    let id: UUID
    var name: String
    var role: Role

    enum Role: String, CaseIterable {
        case owner = "Admin"
        case member = "Mitglied"
    }
}

struct List: Identifiable, Equatable, Hashable {
    let id: UUID
    var name: String
    var isDefault: Bool
    var members: [HouseholdMember]
}

struct Item: Identifiable, Equatable, Hashable {
    let id: UUID
    var name: String
    var quantityText: String?
    var status: Status

    enum Status {
        case open
        case purchased
    }
}

enum BannerState: Equatable {
    case idle
    case processing(message: String)
    case success(message: String)
    case error(message: String)

    var message: String? {
        switch self {
        case .idle: return nil
        case let .processing(message): return message
        case let .success(message): return message
        case let .error(message): return message
        }
    }
}
