import SwiftUI

struct ListDetailView: View {
  @StateObject private var viewModel: ListDetailViewModel

  init(viewModel: ListDetailViewModel) {
    _viewModel = StateObject(wrappedValue: viewModel)
  }

  var body: some View {
    List {
      Section(header: Text("Offen").font(FontTokens.headline)) {
        if viewModel.openItems.isEmpty {
          Text("Keine offenen Artikel")
            .font(FontTokens.body)
            .foregroundStyle(Tokens.textSecondary)
        } else {
          ForEach(viewModel.openItems) { item in
            ItemRow(item: item, onToggle: { viewModel.togglePurchased(item) }, onDelete: { viewModel.delete(item) })
          }
          .listRowBackground(Tokens.surface)
        }
      }

      Section(header: purchasedHeader) {
        if viewModel.showPurchased {
          ForEach(viewModel.purchasedItems) { item in
            ItemRow(item: item, onToggle: { viewModel.togglePurchased(item) }, onDelete: { viewModel.delete(item) })
          }
          .listRowBackground(Tokens.surface)
        }
      }
    }
    .listStyle(.insetGrouped)
    .background(Tokens.bgPrimary)
    .navigationTitle(viewModel.list.name)
    .searchable(text: $viewModel.searchText, placement: .navigationBarDrawer(displayMode: .always))
    .toolbar {
      if viewModel.undoItem != nil {
        ToolbarItem(placement: .bottomBar) {
          Button("Rückgängig") { viewModel.undoLast() }
            .buttonStyle(PrimaryButtonStyle())
        }
      }
    }
    .onAppear(perform: viewModel.reload)
  }

  private var purchasedHeader: some View {
    HStack {
      Text("Erledigt")
        .font(FontTokens.headline)
      Spacer()
      Button(action: { withAnimation { viewModel.showPurchased.toggle() } }) {
        Image(systemName: viewModel.showPurchased ? "chevron.up" : "chevron.down")
      }
      .buttonStyle(.plain)
    }
    .textCase(nil)
  }
}
