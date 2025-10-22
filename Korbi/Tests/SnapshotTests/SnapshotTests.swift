import XCTest
import SwiftUI
import Combine
import UIKit
@testable import Korbi

final class SnapshotTests: XCTestCase {
  func testHomeViewLight() {
    captureHomeView(style: .light, name: "HomeView-Light")
  }

  func testHomeViewDark() {
    captureHomeView(style: .dark, name: "HomeView-Dark")
  }

  private func captureHomeView(style: UIUserInterfaceStyle, name: String) {
    let appState = AppState()
    let listID = UUID()
    appState.households = [HouseholdEntity(id: UUID(), name: "Testhaushalt", role: .owner, createdAt: Date())]
    appState.activeHouseholdID = appState.households.first?.id
    let items = [
      ItemEntity(id: UUID(), listID: listID, name: "Tomaten", quantityText: "500 g", quantityNumeric: nil, unit: nil, status: .open, position: 0, createdAt: Date(), purchasedAt: nil, createdBy: nil, purchasedBy: nil),
      ItemEntity(id: UUID(), listID: listID, name: "Brot", quantityText: "1", quantityNumeric: nil, unit: nil, status: .purchased, position: 1, createdAt: Date().addingTimeInterval(-1000), purchasedAt: Date(), createdBy: nil, purchasedBy: nil)
    ]
    appState.lists = [ListEntity(id: listID, householdID: appState.activeHouseholdID!, name: "Zu kaufen", isDefault: true, createdAt: Date(), items: items)]
    appState.items[listID] = items

    let viewModel = HomeViewModel(appState: appState, itemsService: SnapshotItemsService(), voiceService: SnapshotVoiceService())
    let view = HomeView(viewModel: viewModel).environmentObject(appState)
    let controller = UIHostingController(rootView: view)
    controller.overrideUserInterfaceStyle = style
    controller.view.frame = CGRect(origin: .zero, size: CGSize(width: 390, height: 844))

    let window = UIWindow(frame: controller.view.frame)
    window.rootViewController = controller
    window.makeKeyAndVisible()

    let renderer = UIGraphicsImageRenderer(bounds: controller.view.bounds)
    let image = renderer.image { ctx in
      controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
    }
    let attachment = XCTAttachment(image: image)
    attachment.lifetime = .keepAlways
    attachment.name = name
    add(attachment)
  }
}

private final class SnapshotItemsService: ItemsServicing {
  var realtimeService: RealtimeServicing?

  func loadItems(for listID: UUID) async throws {}
  func addItem(name: String, quantityText: String?, listID: UUID) async throws {}
  func updateItem(_ item: ItemEntity) async throws {}
  func deleteItem(id: UUID) async throws {}
  func togglePurchased(item: ItemEntity) async throws {}
}

private struct SnapshotVoiceService: VoiceServicing {
  var statePublisher: AnyPublisher<VoiceSessionState, Never> {
    Just(VoiceSessionState()).eraseToAnyPublisher()
  }

  func startRecording(householdID: UUID, listID: UUID, userID: UUID) async throws {}
  func stopRecording() async throws {}
  func cancelRecording() {}
}
