import Foundation

enum MockData {
    static let members: [HouseholdMember] = [
        HouseholdMember(id: UUID(), name: "Leonie", role: .owner),
        HouseholdMember(id: UUID(), name: "Max", role: .member),
        HouseholdMember(id: UUID(), name: "Samira", role: .member)
    ]

    static let household = Household(
        id: UUID(),
        name: "WG Korbi",
        members: members
    )

    static let lists: [List] = [
        List(id: UUID(), name: "Wocheneinkauf", isDefault: true, members: members),
        List(id: UUID(), name: "Drogerie", isDefault: false, members: members.dropFirst().map { $0 }),
        List(id: UUID(), name: "Baumarkt", isDefault: false, members: members)
    ]

    static let openItems: [Item] = [
        Item(id: UUID(), name: "Hafermilch", quantityText: "2 x 1L", status: .open),
        Item(id: UUID(), name: "Bananen", quantityText: "6 Stück", status: .open),
        Item(id: UUID(), name: "Kaffee", quantityText: "1 Packung", status: .open),
        Item(id: UUID(), name: "Salat", quantityText: nil, status: .open)
    ]

    static let purchasedItems: [Item] = [
        Item(id: UUID(), name: "Haferflocken", quantityText: "500g", status: .purchased),
        Item(id: UUID(), name: "Tofu", quantityText: "3 Stück", status: .purchased)
    ]
}
