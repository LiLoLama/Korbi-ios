import SwiftUI

struct ListsView: View {
  @ObservedObject var viewModel: ListsViewModel
  @EnvironmentObject private var appState: AppState
  @State private var path: [ListEntity] = []

  var body: some View {
    NavigationStack(path: $path) {
      List(filteredLists) { list in
        Button {
          path.append(list)
        } label: {
          HStack {
            VStack(alignment: .leading, spacing: 4) {
              Text(list.name)
                .font(FontTokens.body)
                .foregroundStyle(Tokens.textPrimary)
              if list.isDefault {
                Text("Standardliste")
                  .font(FontTokens.caption)
                  .foregroundStyle(Tokens.textSecondary)
              }
            }
            Spacer()
            Image(systemName: "chevron.right")
              .foregroundStyle(Tokens.textSecondary)
          }
          .padding(.vertical, 8)
        }
        .accessibilityHint("Liste öffnen")
      }
      .listStyle(.insetGrouped)
      .navigationTitle("Listen")
      .toolbar {
        ToolbarItem(placement: .primaryAction) {
          Button(action: viewModel.createList) {
            Image(systemName: "plus")
          }
          .accessibilityLabel("Liste erstellen")
        }
      }
      .searchable(text: $viewModel.searchText)
      .onAppear(perform: viewModel.refresh)
      .navigationDestination(for: ListEntity.self) { list in
        ListDetailView(viewModel: viewModel.detailViewModel(for: list))
      }
    }
  }
}

private extension ListsView {
  var filteredLists: [ListEntity] {
    guard !viewModel.searchText.isEmpty else { return viewModel.lists }
    return viewModel.lists.filter { $0.name.localizedCaseInsensitiveContains(viewModel.searchText) }
  }
}
