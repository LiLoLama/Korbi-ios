import Foundation
import Combine

@MainActor
final class ListsViewModel: ObservableObject {
  @Published var searchText: String = ""
  @Published var selectedListID: UUID?
  @Published private(set) var lists: [ListEntity] = []

  private let appState: AppState
  private let itemsService: ItemsServicing
  private let listsService: ListsServicing
  private var cancellables: Set<AnyCancellable> = []

  init(appState: AppState, itemsService: ItemsServicing, listsService: ListsServicing) {
    self.appState = appState
    self.itemsService = itemsService
    self.listsService = listsService

    appState.$lists
      .receive(on: RunLoop.main)
      .sink { [weak self] lists in
        guard let self else { return }
        self.lists = lists
        if self.selectedListID == nil {
          self.selectedListID = lists.first?.id
        }
      }
      .store(in: &cancellables)
  }

  func refresh() {
    guard let householdID = appState.activeHouseholdID else { return }
    Task { try? await listsService.loadLists(for: householdID) }
  }

  func createList() {
    guard let householdID = appState.activeHouseholdID else { return }
    Task {
      try await listsService.createList(name: "Neue Liste", householdID: householdID)
    }
  }

  func detailViewModel(for list: ListEntity) -> ListDetailViewModel {
    ListDetailViewModel(list: list, appState: appState, itemsService: itemsService)
  }
}
