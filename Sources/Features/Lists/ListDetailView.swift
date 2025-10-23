import SwiftUI

struct ListDetailView: View {
    @ObservedObject var viewModel: ListViewModel
    let list: ShoppingList

    @State private var itemToDelete: Item?
    @State private var showDeleteConfirmation = false

    var body: some View {
        List {
            Section(header: Text("Offen").font(Typography.headline)) {
                if viewModel.filteredOpenItems.isEmpty {
                    Text("Keine offenen Artikel")
                        .foregroundStyle(Tokens.textSecondary)
                        .padding(.vertical, Spacing.small)
                } else {
                    ForEach(viewModel.filteredOpenItems) { item in
                        ItemRow(
                            item: item,
                            togglePurchased: { viewModel.markPurchased(item) },
                            delete: {
                                itemToDelete = item
                                showDeleteConfirmation = true
                            }
                        )
                    }
                }
            }

            Section {
                DisclosureGroup(isExpanded: Binding(
                    get: { !viewModel.isPurchasedCollapsed },
                    set: { viewModel.isPurchasedCollapsed = !$0 }
                )) {
                    if viewModel.filteredPurchasedItems.isEmpty {
                        Text("Keine gekauften Artikel")
                            .foregroundStyle(Tokens.textSecondary)
                            .padding(.vertical, Spacing.small)
                    } else {
                        ForEach(viewModel.filteredPurchasedItems) { item in
                            ItemRow(
                                item: item,
                                togglePurchased: { viewModel.markPurchased(item) },
                                delete: {
                                    itemToDelete = item
                                    showDeleteConfirmation = true
                                }
                            )
                        }
                    }
                } label: {
                    Text("Gekauft")
                        .font(Typography.headline)
                        .foregroundStyle(Tokens.textPrimary)
                }
            }
        }
        .listStyle(.insetGrouped)
        .searchable(text: $viewModel.searchText, placement: .automatic, prompt: Text("Artikel suchen"))
        .navigationTitle(list.name)
        .background(Tokens.bgPrimary)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        viewModel.isPurchasedCollapsed.toggle()
                    }
                } label: {
                    Label(
                        viewModel.isPurchasedCollapsed ? "Gekauft anzeigen" : "Gekauft verbergen",
                        systemImage: viewModel.isPurchasedCollapsed ? "chevron.down" : "chevron.up"
                    )
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 12) {
            if let undoItem = viewModel.undoItem {
                Banner(style: .info, message: "\(undoItem.name) erledigt. Rückgängig?") {
                    viewModel.undoLastAction()
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .padding(.horizontal)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if viewModel.bannerState != .idle {
                bannerView(for: viewModel.bannerState)
                    .padding()
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .confirmationDialog(
            "Artikel löschen?",
            isPresented: $showDeleteConfirmation,
            presenting: itemToDelete
        ) { item in
            Button("Löschen", role: .destructive) {
                viewModel.delete(item)
            }
        } message: { item in
            Text("\(item.name) entfernen?")
        }
        .task {
            viewModel.select(list: list)
        }
    }

    @ViewBuilder
    private func bannerView(for state: BannerState) -> some View {
        switch state {
        case let .processing(message):
            Banner(style: .info, message: message) {
                viewModel.bannerState = .idle
            }
        case let .success(message):
            Banner(style: .success, message: message) {
                viewModel.bannerState = .idle
            }
        case let .error(message):
            Banner(style: .error, message: message) {
                viewModel.bannerState = .idle
            }
        case .idle:
            EmptyView()
        }
    }
}

#Preview("ListDetailView") {
    let viewModel = ListViewModel(
        listsService: ListsFakeService(),
        itemsService: ItemsFakeService()
    )
    return NavigationStack {
        ListDetailView(viewModel: viewModel, list: MockData.lists.first!)
    }
}
