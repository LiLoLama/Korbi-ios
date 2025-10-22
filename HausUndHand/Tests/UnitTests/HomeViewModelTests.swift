import XCTest
import Combine
@testable import HausUndHand

final class HomeViewModelTests: XCTestCase {
  func testQuickAddIgnoresWhitespace() async {
    let appState = AppState()
    let itemsService = ItemsServiceMock()
    let voiceService = VoiceServiceStub()
    let viewModel = await MainActor.run { HomeViewModel(appState: appState, itemsService: itemsService, voiceService: voiceService) }
    let listID = UUID()
    appState.lists = [ListEntity(id: listID, householdID: UUID(), name: "Zu kaufen", isDefault: true, createdAt: Date(), items: [])]
    appState.items[listID] = []

    await MainActor.run {
      viewModel.quickAddText = "   "
      viewModel.addQuickItem()
    }

    XCTAssertEqual(itemsService.addedItems.count, 0)
  }
}

final class ItemsServiceMock: ItemsServicing {
  var realtimeService: RealtimeServicing?
  private(set) var addedItems: [(name: String, quantity: String?, listID: UUID)] = []

  func loadItems(for listID: UUID) async throws {}

  func addItem(name: String, quantityText: String?, listID: UUID) async throws {
    addedItems.append((name, quantityText, listID))
  }

  func updateItem(_ item: ItemEntity) async throws {}
  func deleteItem(id: UUID) async throws {}
  func togglePurchased(item: ItemEntity) async throws {}
}

struct VoiceServiceStub: VoiceServicing {
  var statePublisher: AnyPublisher<VoiceSessionState, Never> {
    Just(VoiceSessionState()).eraseToAnyPublisher()
  }

  func startRecording(householdID: UUID, listID: UUID, userID: UUID) async throws {}
  func stopRecording() async throws {}
  func cancelRecording() {}
}
