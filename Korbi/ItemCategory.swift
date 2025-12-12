import Foundation

enum ListColorRole {
    case primary
    case accent
    case pantry
}

enum ItemCategory: String, CaseIterable, Identifiable {
    case produce = "Obst & Gemüse"
    case bakery = "Backwaren & Frühstück"
    case dairy = "Milch & Kühlware"
    case pantry = "Vorrat & Konserven"
    case sweets = "Süßes & Snacks"
    case drinks = "Getränke"
    case frozen = "Tiefkühl"
    case personalCare = "Drogerie & Körperpflege"
    case household = "Haushalt & Reinigung"
    case pets = "Tierbedarf"
    case baby = "Baby & Kind"
    case other = "Sonstiges"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .produce:
            return "leaf.fill"
        case .bakery:
            return "bag.fill"
        case .dairy:
            return "drop.fill"
        case .pantry:
            return "shippingbox.fill"
        case .sweets:
            return "heart.fill"
        case .drinks:
            return "wineglass.fill"
        case .frozen:
            return "snowflake"
        case .personalCare:
            return "hand.raised.fill"
        case .household:
            return "house.fill"
        case .pets:
            return "pawprint.fill"
        case .baby:
            return "person.2.fill"
        case .other:
            return "ellipsis.circle"
        }
    }

    var colorRole: ListColorRole {
        switch self {
        case .produce, .dairy, .drinks, .pets, .other:
            return .primary
        case .bakery, .sweets, .personalCare, .baby:
            return .accent
        case .pantry, .frozen, .household:
            return .pantry
        }
    }
}
