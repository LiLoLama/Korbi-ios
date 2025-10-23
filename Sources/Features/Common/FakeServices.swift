import Foundation

protocol FailureConfigurable {
    func simulateNextFailure() async
}

protocol HouseholdServicing {
    func fetchHousehold() async throws -> Household
    func fetchMembers() async throws -> [HouseholdMember]
}

protocol ListsServicing {
    func fetchLists() async throws -> [ShoppingList]
    func defaultList() async throws -> ShoppingList
}

protocol ItemsServicing {
    func fetchItems(for list: ShoppingList) async throws -> (open: [Item], purchased: [Item])
    func mark(_ item: Item, purchased: Bool, in list: ShoppingList) async throws -> (open: [Item], purchased: [Item])
    func delete(_ item: Item, in list: ShoppingList) async throws -> (open: [Item], purchased: [Item])
}

enum FakeServiceError: Error, LocalizedError {
    case randomFailure

    var errorDescription: String? {
        switch self {
        case .randomFailure: return "Ups, gerade nicht erreichbar."
        }
    }
}

actor FakeDelayProvider {
    private var shouldFail = false

    func nextDelay() async throws {
        try await Task.sleep(nanoseconds: UInt64(Int.random(in: 300...800)) * 1_000_000)
        if shouldFail {
            shouldFail = false
            throw FakeServiceError.randomFailure
        }
    }

    func injectFailure() {
        shouldFail = true
    }
}

final class HouseholdFakeService: HouseholdServicing, FailureConfigurable {
    private let delay = FakeDelayProvider()
    private var household: Household = MockData.household

    func fetchHousehold() async throws -> Household {
        try await delay.nextDelay()
        return household
    }

    func fetchMembers() async throws -> [HouseholdMember] {
        try await delay.nextDelay()
        return household.members
    }

    func simulateNextFailure() async {
        await delay.injectFailure()
    }
}

final class ListsFakeService: ListsServicing, FailureConfigurable {
    private let delay = FakeDelayProvider()
    private var lists: [ShoppingList] = MockData.lists

    func fetchLists() async throws -> [ShoppingList] {
        try await delay.nextDelay()
        return lists
    }

    func defaultList() async throws -> ShoppingList {
        try await delay.nextDelay()
        guard let list = lists.first(where: { $0.isDefault }) else {
            return lists.first ?? MockData.lists[0]
        }
        return list
    }

    func simulateNextFailure() async {
        await delay.injectFailure()
    }
}

final class ItemsFakeService: ItemsServicing, FailureConfigurable {
    private let delay = FakeDelayProvider()
    private var openItems: [UUID: [Item]] = [:]
    private var purchasedItems: [UUID: [Item]] = [:]

    init() {
        let defaultList = MockData.lists.first!
        openItems[defaultList.id] = MockData.openItems
        purchasedItems[defaultList.id] = MockData.purchasedItems
        for list in MockData.lists.dropFirst() {
            openItems[list.id] = MockData.openItems.shuffled()
            purchasedItems[list.id] = MockData.purchasedItems.shuffled()
        }
    }

    func fetchItems(for list: ShoppingList) async throws -> (open: [Item], purchased: [Item]) {
        try await delay.nextDelay()
        return (
            openItems[list.id] ?? [],
            purchasedItems[list.id] ?? []
        )
    }

    func mark(_ item: Item, purchased: Bool, in list: ShoppingList) async throws -> (open: [Item], purchased: [Item]) {
        try await delay.nextDelay()
        var open = openItems[list.id] ?? []
        var done = purchasedItems[list.id] ?? []

        open.removeAll { $0.id == item.id }
        done.removeAll { $0.id == item.id }

        var updated = item
        updated.status = purchased ? .purchased : .open

        if purchased {
            done.insert(updated, at: 0)
        } else {
            open.insert(updated, at: 0)
        }

        openItems[list.id] = open
        purchasedItems[list.id] = done
        return (open, done)
    }

    func delete(_ item: Item, in list: ShoppingList) async throws -> (open: [Item], purchased: [Item]) {
        try await delay.nextDelay()
        var open = openItems[list.id] ?? []
        var done = purchasedItems[list.id] ?? []
        open.removeAll { $0.id == item.id }
        done.removeAll { $0.id == item.id }
        openItems[list.id] = open
        purchasedItems[list.id] = done
        return (open, done)
    }

    func simulateNextFailure() async {
        await delay.injectFailure()
    }
}
