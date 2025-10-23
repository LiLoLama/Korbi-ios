import Foundation
import SwiftUI

@MainActor
final class ListViewModel: ObservableObject {
    @Published var lists: [List] = []
    @Published var selectedList: List?
    @Published var openItems: [Item] = []
    @Published var purchasedItems: [Item] = []
    @Published var searchText: String = ""
    @Published var isPurchasedCollapsed = true
    @Published var undoItem: Item?
    @Published var bannerState: BannerState = .idle

    private let listsService: ListsServicing
    private let itemsService: ItemsServicing
    private var undoTask: Task<Void, Never>?

    init(
        listsService: ListsServicing,
        itemsService: ItemsServicing
    ) {
        self.listsService = listsService
        self.itemsService = itemsService
    }

    var filteredOpenItems: [Item] {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return openItems
        }
        return openItems.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var filteredPurchasedItems: [Item] {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return purchasedItems
        }
        return purchasedItems.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    func onAppear() {
        Task { await loadLists() }
    }

    func loadLists() async {
        do {
            let fetched = try await listsService.fetchLists()
            lists = fetched
            if selectedList == nil {
                selectedList = fetched.first
            }
            if let list = selectedList {
                undoItem = nil
                try await loadItems(for: list)
            }
        } catch {
            bannerState = .error(message: error.localizedDescription)
        }
    }

    func loadItems(for list: List) async throws {
        let result = try await itemsService.fetchItems(for: list)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
            openItems = result.open
            purchasedItems = result.purchased
        }
    }

    func select(list: List) {
        guard list.id != selectedList?.id else { return }
        selectedList = list
        undoItem = nil
        Task {
            do {
                try await loadItems(for: list)
            } catch {
                bannerState = .error(message: error.localizedDescription)
            }
        }
    }

    func markPurchased(_ item: Item) {
        guard let list = selectedList else { return }
        undoTask?.cancel()
        KorbiHaptics.lightImpact()

        Task {
            do {
                let result = try await itemsService.mark(item, purchased: item.status == .open, in: list)
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                    openItems = result.open
                    purchasedItems = result.purchased
                    undoItem = item
                }
                scheduleUndo(for: item)
            } catch {
                bannerState = .error(message: error.localizedDescription)
            }
        }
    }

    func undoLastAction() {
        guard let item = undoItem, let list = selectedList else { return }
        undoTask?.cancel()
        Task {
            do {
                let result = try await itemsService.mark(item, purchased: false, in: list)
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                    openItems = result.open
                    purchasedItems = result.purchased
                }
            } catch {
                bannerState = .error(message: error.localizedDescription)
            }
            undoItem = nil
        }
    }

    func delete(_ item: Item) {
        guard let list = selectedList else { return }
        Task {
            do {
                let result = try await itemsService.delete(item, in: list)
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                    openItems = result.open
                    purchasedItems = result.purchased
                }
            } catch {
                bannerState = .error(message: error.localizedDescription)
            }
        }
    }

    private func scheduleUndo(for item: Item) {
        undoTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            await MainActor.run {
                guard let self else { return }
                withAnimation(.easeInOut) {
                    undoItem = nil
                }
            }
        }
    }
}
