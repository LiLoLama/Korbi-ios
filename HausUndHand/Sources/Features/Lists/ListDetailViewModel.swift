import Foundation
import Combine

@MainActor
final class ListDetailViewModel: ObservableObject {
  @Published private(set) var list: ListEntity
  @Published private(set) var openItems: [ItemEntity] = []
  @Published private(set) var purchasedItems: [ItemEntity] = []
  @Published var showPurchased: Bool = false
  @Published var searchText: String = "" {
    didSet {
      if let items = appState.items[list.id] {
        apply(items: items)
      }
    }
  }
  @Published var undoItem: ItemEntity?
  @Published var banner: Banner.Style?

  private let appState: AppState
  private let itemsService: ItemsServicing
  private var cancellables: Set<AnyCancellable> = []
  private var undoTask: Task<Void, Never>?

  init(list: ListEntity, appState: AppState, itemsService: ItemsServicing) {
    self.list = list
    self.appState = appState
    self.itemsService = itemsService

    appState.$items
      .receive(on: RunLoop.main)
      .sink { [weak self] map in
        guard let self else { return }
        guard let items = map[list.id] else {
          self.openItems = []
          self.purchasedItems = []
          return
        }
        self.apply(items: items)
      }
      .store(in: &cancellables)
  }

  private func apply(items: [ItemEntity]) {
    let filtered = items.filter { item in
      guard !searchText.isEmpty else { return true }
      return item.name.localizedCaseInsensitiveContains(searchText)
    }
    openItems = filtered.filter { $0.status == .open }.sorted { $0.createdAt > $1.createdAt }
    purchasedItems = filtered.filter { $0.status == .purchased }.sorted { $0.purchasedAt ?? Date.distantPast > $1.purchasedAt ?? Date.distantPast }
  }

  func reload() {
    Task { try? await itemsService.loadItems(for: list.id) }
  }

  func togglePurchased(_ item: ItemEntity) {
    undoTask?.cancel()
    Task {
      do {
        try await itemsService.togglePurchased(item: item)
        undoItem = item
        undoTask = Task { [weak self] in
          try? await Task.sleep(nanoseconds: 5_000_000_000)
          await MainActor.run {
            self?.undoItem = nil
          }
        }
      } catch {
        banner = .error("Aktion fehlgeschlagen")
      }
    }
  }

  func undoLast() {
    guard let undoItem else { return }
    undoTask?.cancel()
    Task {
      try? await itemsService.togglePurchased(item: undoItem)
      await MainActor.run { self.undoItem = nil }
    }
  }

  func delete(_ item: ItemEntity) {
    Task {
      try? await itemsService.deleteItem(id: item.id)
    }
  }
}
