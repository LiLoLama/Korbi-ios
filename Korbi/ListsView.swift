import SwiftUI

struct ShoppingListSummary: Identifiable {
    let id = UUID()
    let category: ItemCategory

    var title: String { category.rawValue }
    var colorRole: ListColorRole { category.colorRole }
    var icon: String { category.icon }
}

struct ListsView: View {
    @EnvironmentObject private var settings: KorbiSettings
    @EnvironmentObject private var authManager: AuthManager
    private let lists: [ShoppingListSummary] = ItemCategory.allCases.map { category in
        ShoppingListSummary(category: category)
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                KorbiBackground()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        LazyVStack(spacing: 20) {
                            ForEach(lists) { list in
                                NavigationLink(destination: listDetail(list)) {
                                    ListCard(summary: list)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .padding(.bottom, 48)
                }
            }
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(settings.palette.background.opacity(0.9), for: .navigationBar)
            .navigationTitle("Listen")
        }
    }

    private func listDetail(_ summary: ShoppingListSummary) -> some View {
        ListDetailView(summary: summary)
    }
}

private struct ListCard: View {
    @EnvironmentObject private var settings: KorbiSettings
    let summary: ShoppingListSummary

    var body: some View {
        KorbiCard {
            HStack(alignment: .center, spacing: 20) {
                ZStack {
                    RoundedRectangle(cornerRadius: KorbiTheme.Metrics.compactCornerRadius, style: .continuous)
                        .fill(color.opacity(0.18))
                    Image(systemName: summary.icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(color)
                }
                .frame(width: 58, height: 58)

                Text(summary.title)
                    .font(KorbiTheme.Typography.body(weight: .semibold))
                    .foregroundStyle(settings.palette.textPrimary)
                Text(itemCountText)
                    .font(KorbiTheme.Typography.caption(weight: .semibold))
                    .foregroundStyle(settings.palette.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(settings.palette.primary.opacity(0.15))
                    .clipShape(Capsule())
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(settings.palette.primary.opacity(0.7))
            }
        }
        .padding(.vertical, 4)
    }

    private var itemCount: Int {
        settings.items(for: summary.title).count
    }

    private var itemCountText: String {
        let count = itemCount
        if count == 1 {
            return "1 Artikel"
        } else {
            return "\(count) Artikel"
        }
    }

    private var color: Color {
        switch summary.colorRole {
        case .primary:
            return settings.palette.primary
        case .accent:
            return settings.palette.accent
        case .pantry:
            return Color(red: 0.62, green: 0.53, blue: 0.39)
        }
    }
}

#Preview {
    ListsView()
        .environmentObject(KorbiSettings())
        .environmentObject(AuthManager())
}

private struct ListDetailView: View {
    @EnvironmentObject private var settings: KorbiSettings
    @EnvironmentObject private var authManager: AuthManager
    let summary: ShoppingListSummary
    @State private var purchasedItems: Set<UUID> = []
    @State private var editingItem: HouseholdItem?
    @State private var editedItemName = ""
    @State private var editedItemDescription = ""
    @State private var editedItemQuantity = ""
    @State private var editedItemCategory = ""
    @State private var isUpdatingItem = false
    @State private var itemEditErrorMessage: String?
    @State private var longPressFeedbackItemID: UUID?

    var body: some View {
        List {
            if items.isEmpty {
                Text("Keine Artikel in dieser Kategorie.")
                    .font(KorbiTheme.Typography.body())
                    .foregroundStyle(settings.palette.textSecondary)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(items) { item in
                    ItemRowView(
                        item: item,
                        state: purchasedItems.contains(item.id) ? .confirmed : .normal
                    )
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .scaleEffect(longPressFeedbackItemID == item.id ? 0.98 : 1.0)
                    .shadow(
                        color: settings.palette.primary.opacity(longPressFeedbackItemID == item.id ? 0.18 : 0),
                        radius: longPressFeedbackItemID == item.id ? 8 : 0,
                        x: 0,
                        y: 4
                    )
                    .animation(.easeInOut(duration: 0.18), value: longPressFeedbackItemID)
                    .onLongPressGesture(minimumDuration: 0.4, maximumDistance: 18, pressing: { isPressing in
                        withAnimation(.easeInOut(duration: 0.14)) {
                            longPressFeedbackItemID = isPressing ? item.id : nil
                        }
                    }) {
                        presentEditor(for: item)
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button {
                            _ = withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                purchasedItems.insert(item.id)
                            }
                            Task {
                                try? await Task.sleep(nanoseconds: 350_000_000)
                                await settings.markItemAsPurchased(item)
                                _ = await MainActor.run {
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        purchasedItems.remove(item.id)
                                    }
                                }
                            }
                        } label: {
                            Label("Gekauft", systemImage: "checkmark")
                        }
                        .tint(.green)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(KorbiBackground())
        .listStyle(.plain)
        .navigationTitle(summary.title)
        .sheet(item: $editingItem) { item in
            editItemSheet(for: item)
        }
    }


    @ViewBuilder
    private func editItemSheet(for item: HouseholdItem) -> some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                TextField("Name", text: $editedItemName)
                    .textInputAutocapitalization(.sentences)
                    .autocorrectionDisabled(false)
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(settings.palette.card.opacity(0.8)))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(settings.palette.outline.opacity(0.7), lineWidth: 1)
                    )

                TextField("Beschreibung", text: $editedItemDescription, axis: .vertical)
                    .textInputAutocapitalization(.sentences)
                    .autocorrectionDisabled(false)
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(settings.palette.card.opacity(0.8)))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(settings.palette.outline.opacity(0.7), lineWidth: 1)
                    )

                HStack(spacing: 12) {
                    TextField("Menge", text: $editedItemQuantity)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(settings.palette.card.opacity(0.8)))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(settings.palette.outline.opacity(0.7), lineWidth: 1)
                        )

                    editCategoryPicker
                }

                if let errorMessage = itemEditErrorMessage {
                    Text(errorMessage)
                        .font(KorbiTheme.Typography.caption())
                        .foregroundStyle(Color.red)
                }

                Button(action: submitItemUpdate) {
                    HStack {
                        if isUpdatingItem {
                            ProgressView()
                                .tint(.white)
                        }
                        Text("Änderungen speichern")
                            .font(KorbiTheme.Typography.body(weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(settings.palette.primary)
                .disabled(isUpdatingItem || editedItemName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .background(KorbiBackground())
            .navigationTitle("Artikel bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        dismissEditor()
                    }
                    .disabled(isUpdatingItem)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .onAppear {
            editedItemName = item.name
            editedItemDescription = item.description
            editedItemQuantity = item.quantity
            editedItemCategory = item.category
            itemEditErrorMessage = nil
        }
    }

    private var editCategoryPicker: some View {
        Menu {
            ForEach(ItemCategory.allCases) { category in
                Button {
                    editedItemCategory = category.rawValue
                } label: {
                    HStack {
                        Text(category.rawValue)
                        if editedItemCategory == category.rawValue {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }

            if !editedItemCategory.isEmpty {
                Divider()
                Button("Keine Kategorie") {
                    editedItemCategory = ""
                }
            }
        } label: {
            HStack {
                Text(editedItemCategory.isEmpty ? "Kategorie" : editedItemCategory)
                    .font(KorbiTheme.Typography.caption(weight: .semibold))
                    .foregroundStyle(settings.palette.textSecondary)
                    .lineLimit(1)

                Spacer()

                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(settings.palette.primary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12).fill(settings.palette.card.opacity(0.8)))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(settings.palette.outline.opacity(0.7), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Kategorie auswählen")
    }

    private func presentEditor(for item: HouseholdItem) {
        longPressFeedbackItemID = nil
        editingItem = item
    }

    private func dismissEditor() {
        editingItem = nil
        longPressFeedbackItemID = nil
        itemEditErrorMessage = nil
    }

    private func submitItemUpdate() {
        guard !isUpdatingItem, let item = editingItem else { return }

        let trimmedName = editedItemName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            itemEditErrorMessage = ItemUpdateError.invalidName.errorDescription
            return
        }

        itemEditErrorMessage = nil
        isUpdatingItem = true

        Task {
            do {
                try await settings.updateItem(
                    item,
                    name: trimmedName,
                    description: editedItemDescription,
                    quantity: editedItemQuantity,
                    category: editedItemCategory
                )

                await MainActor.run {
                    isUpdatingItem = false
                    dismissEditor()
                }
            } catch {
                let localizedError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                await MainActor.run {
                    itemEditErrorMessage = localizedError
                    isUpdatingItem = false
                }
            }
        }
    }

    private var items: [HouseholdItem] {
        settings.items(for: summary.title)
    }
}

struct ItemRowView: View {
    @EnvironmentObject private var settings: KorbiSettings
    let item: HouseholdItem
    let state: CompletionState

    enum CompletionState: Equatable {
        case normal
        case prompt
        case confirmed
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: KorbiTheme.Metrics.compactCornerRadius, style: .continuous)
                .fill(rowBackgroundColor)
                .animation(.easeInOut(duration: 0.3), value: state)

            VStack(alignment: .center, spacing: 6) {
                Text(item.name)
                    .font(KorbiTheme.Typography.body(weight: .semibold))
                    .foregroundStyle(settings.palette.textPrimary)
                    .multilineTextAlignment(.center)

                if !item.quantity.isEmpty {
                    Text(item.quantity)
                        .font(KorbiTheme.Typography.caption())
                        .foregroundStyle(settings.palette.primary.opacity(0.7))
                        .multilineTextAlignment(.center)
                }

                if !item.description.isEmpty {
                    Text(item.description)
                        .font(KorbiTheme.Typography.body())
                        .foregroundStyle(settings.palette.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 12)
        .overlay { overlayView }
    }

    private var rowBackgroundColor: Color {
        switch state {
        case .confirmed:
            return Color.green.opacity(0.25)
        case .prompt:
            return settings.palette.card.opacity(0.85)
        case .normal:
            return settings.palette.card.opacity(0.7)
        }
    }

    @ViewBuilder
    private var overlayView: some View {
        switch state {
        case .prompt:
            RoundedRectangle(cornerRadius: KorbiTheme.Metrics.compactCornerRadius, style: .continuous)
                .fill(Color.green.opacity(0.88))
                .overlay {
                    HStack(spacing: 12) {
                        Image(systemName: "hand.tap.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white)

                        Text("Erledigt?")
                            .font(KorbiTheme.Typography.body(weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity)
                }
                .shadow(color: Color.green.opacity(0.35), radius: 12, x: 0, y: 6)
                .transition(.opacity.combined(with: .scale))
                .allowsHitTesting(false)
        case .confirmed:
            RoundedRectangle(cornerRadius: KorbiTheme.Metrics.compactCornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.green.opacity(0.95), Color.green.opacity(0.75)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white)

                        Text("Erledigt!")
                            .font(KorbiTheme.Typography.body(weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity)
                }
                .shadow(color: Color.green.opacity(0.35), radius: 12, x: 0, y: 6)
                .transition(.opacity.combined(with: .scale))
                .allowsHitTesting(false)
        case .normal:
            EmptyView()
        }
    }
}
