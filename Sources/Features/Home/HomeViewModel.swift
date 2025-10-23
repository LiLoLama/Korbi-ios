import Foundation
import SwiftUI

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var householdName: String = ""
    @Published var items: [Item] = []
    @Published var isRecording = false
    @Published var bannerState: BannerState = .idle
    @Published var simulateEmptyState = false
    @Published var showDebugOptions = false

    private let householdService: HouseholdServicing
    private let listsService: ListsServicing
    private let itemsService: ItemsServicing

    private var currentList: ShoppingList?
    private var recordingTask: Task<Void, Never>?
    private var observers: [NSObjectProtocol] = []

    init(
        householdService: HouseholdServicing,
        listsService: ListsServicing,
        itemsService: ItemsServicing
    ) {
        self.householdService = householdService
        self.listsService = listsService
        self.itemsService = itemsService

        observeDebugNotifications()
    }

    deinit {
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func onAppear() {
        Task {
            await loadData()
        }
    }

    func loadData() async {
        do {
            async let household = householdService.fetchHousehold()
            async let list = listsService.defaultList()
            let householdValue = try await household
            let listValue = try await list
            householdName = householdValue.name
            currentList = listValue
            try await loadItems(for: listValue)
        } catch {
            bannerState = .error(message: error.localizedDescription)
        }
    }

    func loadItems(for list: ShoppingList) async throws {
        let itemsPair = try await itemsService.fetchItems(for: list)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.88)) {
            items = simulateEmptyState ? [] : itemsPair.open
        }
    }

    func toggleEmptyState() {
        simulateEmptyState.toggle()
        if simulateEmptyState {
            withAnimation(.easeInOut(duration: 0.25)) {
                items = []
            }
        } else if let list = currentList {
            Task {
                try? await loadItems(for: list)
            }
        }
    }

    func triggerErrorBanner() {
        bannerState = .error(message: "Simulierter Fehler – bitte erneut versuchen.")
    }

    func startLoadingBanner() {
        bannerState = .processing(message: "Verarbeite Einkaufsliste...")
    }

    func toggleRecording() {
        isRecording.toggle()
        recordingTask?.cancel()

        if isRecording {
            KorbiHaptics.lightImpact()
            bannerState = .processing(message: "Verarbeite Sprachbefehl...")
            recordingTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                await self?.finishRecording(success: true)
            }
        } else {
            finishRecording(success: false)
        }
    }

    func finishRecording(success: Bool) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            isRecording = false
        }
        if success {
            bannerState = .success(message: "Neue Artikel wurden vorgeschlagen.")
        } else if case .processing = bannerState {
            bannerState = .idle
        }
    }

    func dismissBanner() {
        bannerState = .idle
    }

    private func observeDebugNotifications() {
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: .debugSimulateEmptyState, object: nil, queue: .main) { [weak self] _ in
            self?.toggleEmptyState()
        })
        observers.append(center.addObserver(forName: .debugShowErrorBanner, object: nil, queue: .main) { [weak self] _ in
            self?.triggerErrorBanner()
        })
        observers.append(center.addObserver(forName: .debugShowLoadingBanner, object: nil, queue: .main) { [weak self] _ in
            self?.startLoadingBanner()
        })
    }
}
