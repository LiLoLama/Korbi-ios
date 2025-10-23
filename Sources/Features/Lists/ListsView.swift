import SwiftUI

struct ListsView: View {
    @StateObject var viewModel: ListViewModel

    init(viewModel: ListViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            List(viewModel.lists) { list in
                NavigationLink(value: list) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(list.name)
                                .font(Typography.headline)
                                .foregroundStyle(Tokens.textPrimary)
                            Text("\(list.members.count) Mitglieder")
                                .font(Typography.caption)
                                .foregroundStyle(Tokens.textSecondary)
                        }
                        Spacer()
                        if list.isDefault {
                            Label("Standard", systemImage: "star.fill")
                                .font(.caption)
                                .foregroundStyle(Tokens.tintPrimary)
                        }
                    }
                    .padding(.vertical, Spacing.small)
                }
                .accessibilityHint(Text("Öffnet die Detailansicht für \(list.name)"))
            }
            .listStyle(.insetGrouped)
            .navigationDestination(for: List.self) { list in
                ListDetailView(viewModel: viewModel, list: list)
            }
            .navigationTitle("Listen")
            .background(Tokens.bgPrimary)
        }
        .task { viewModel.onAppear() }
    }
}

#Preview("ListsView") {
    ListsView(viewModel: ListViewModel(
        listsService: ListsFakeService(),
        itemsService: ItemsFakeService()
    ))
}
