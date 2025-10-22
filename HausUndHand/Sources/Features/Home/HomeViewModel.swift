import Foundation
import Combine

@MainActor
final class HomeViewModel: ObservableObject {
  @Published private(set) var defaultList: ListEntity?
  @Published private(set) var items: [ItemEntity] = []
  @Published var quickAddText: String = ""
  @Published var banner: Banner.Style?

  private let appState: AppState
  private let itemsService: ItemsServicing
  private let voiceService: VoiceServicing
  private var cancellables: Set<AnyCancellable> = []

  init(appState: AppState, itemsService: ItemsServicing, voiceService: VoiceServicing) {
    self.appState = appState
    self.itemsService = itemsService
    self.voiceService = voiceService

    appState.$lists
      .combineLatest(appState.$activeHouseholdID)
      .sink { [weak self] lists, householdID in
        guard let self else { return }
        self.defaultList = lists.first { $0.isDefault } ?? lists.first
        self.reloadItems()
        if let householdID {
          self.itemsService.realtimeService?.subscribe(to: householdID)
        }
      }
      .store(in: &cancellables)

    appState.$items
      .sink { [weak self] map in
        guard let self else { return }
        if let listID = self.defaultList?.id {
          self.items = map[listID] ?? []
        }
      }
      .store(in: &cancellables)

    voiceService.statePublisher
      .receive(on: RunLoop.main)
      .sink { [weak self] state in
        guard let self else { return }
        switch state.phase {
        case .uploading:
          self.banner = .info("Verarbeite Sprachaufnahme …")
        case .failure(let error):
          self.banner = .error(error)
        default:
          self.banner = nil
        }
      }
      .store(in: &cancellables)
  }

  func reloadItems() {
    guard let listID = defaultList?.id else { return }
    Task {
      try? await itemsService.loadItems(for: listID)
    }
  }

  func addQuickItem() {
    guard let listID = defaultList?.id else { return }
    let trimmed = quickAddText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }
    Task {
      do {
        try await itemsService.addItem(name: trimmed, quantityText: nil, listID: listID)
        quickAddText = ""
      } catch {
        banner = .error("Konnte Artikel nicht anlegen")
      }
    }
  }

  func togglePurchased(item: ItemEntity) {
    Task {
      try? await itemsService.togglePurchased(item: item)
    }
  }

  func delete(item: ItemEntity) {
    Task {
      try? await itemsService.deleteItem(id: item.id)
    }
  }

  func startRecording(userID: UUID) {
    guard let householdID = appState.activeHouseholdID, let listID = defaultList?.id else { return }
    Task {
      do {
        try await voiceService.startRecording(householdID: householdID, listID: listID, userID: userID)
      } catch {
        banner = .error(error.localizedDescription)
      }
    }
  }

  func stopRecording() {
    Task {
      do {
        try await voiceService.stopRecording()
      } catch {
        banner = .error("Upload fehlgeschlagen")
      }
    }
  }
}
