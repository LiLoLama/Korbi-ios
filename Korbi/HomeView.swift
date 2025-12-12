import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var settings: KorbiSettings
    @EnvironmentObject private var authManager: AuthManager
    @State private var purchasedItems: Set<UUID> = []
    @State private var pendingCompletionItemID: UUID?
    @State private var isRefreshing = false
    @State private var newItemName = ""
    @State private var newItemDescription = ""
    @State private var newItemQuantity = ""
    @State private var newItemCategory = ""
    @State private var isSubmittingItem = false
    @State private var itemErrorMessage: String?
    @State private var isManualEntryVisible = false

    var body: some View {
        NavigationStack {
            ZStack {
                KorbiBackground()
                    .contentShape(Rectangle())
                    .onTapGesture(perform: cancelPendingCompletion)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 28) {
                        if isManualEntryVisible {
                            manualEntryCard
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }
                        todaysItems
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                }
                .onChange(of: settings.currentHouseholdItems) { _, items in
                    guard let pendingID = pendingCompletionItemID else { return }
                    if !items.contains(where: { $0.id == pendingID }) {
                        pendingCompletionItemID = nil
                    }
                }
                .safeAreaInset(edge: .bottom) {
                    ZStack(alignment: .bottomTrailing) {
                        FloatingMicButton()
                            .padding(.top, 16)
                            .padding(.bottom, 24)
                            .frame(maxWidth: .infinity, alignment: .center)

                        manualEntryToggleButton
                            .padding(.trailing, 18)
                            .padding(.bottom, 10)
                    }
                }
            }
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(settings.palette.background.opacity(0.85), for: .navigationBar)
            .navigationTitle("Korbi")
            .navigationBarTitleDisplayMode(.large)
        }
        .accentColor(settings.palette.primary)
    }

    private var manualEntryToggleButton: some View {
        Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                isManualEntryVisible.toggle()
            }
        } label: {
            Image(systemName: isManualEntryVisible ? "xmark" : "square.and.pencil")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 60, height: 60)
                .background(
                    Circle()
                        .fill(settings.palette.primary)
                        .shadow(color: settings.palette.primary.opacity(0.3), radius: 8, x: 0, y: 6)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isManualEntryVisible ? "Eingabe schließen" : "Artikel manuell hinzufügen")
    }

    private var manualEntryCard: some View {
        KorbiCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Artikel manuell hinzufügen")
                    .font(KorbiTheme.Typography.title(weight: .semibold))
                    .foregroundStyle(settings.palette.textPrimary)

                VStack(spacing: 10) {
                    TextField("Name", text: $newItemName)
                        .textInputAutocapitalization(.sentences)
                        .autocorrectionDisabled(false)
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(settings.palette.card.opacity(0.8)))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(settings.palette.outline.opacity(0.7), lineWidth: 1)
                        )

                    TextField("Beschreibung", text: $newItemDescription, axis: .vertical)
                        .textInputAutocapitalization(.sentences)
                        .autocorrectionDisabled(false)
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(settings.palette.card.opacity(0.8)))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(settings.palette.outline.opacity(0.7), lineWidth: 1)
                        )

                    HStack(spacing: 12) {
                        TextField("Menge", text: $newItemQuantity)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: 12).fill(settings.palette.card.opacity(0.8)))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(settings.palette.outline.opacity(0.7), lineWidth: 1)
                            )

                        categoryPicker
                    }
                }

                if let errorMessage = itemErrorMessage {
                    Text(errorMessage)
                        .font(KorbiTheme.Typography.caption())
                        .foregroundStyle(Color.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button(action: submitManualItem) {
                    HStack {
                        if isSubmittingItem {
                            ProgressView()
                                .tint(.white)
                        }
                        Text("Speichern")
                            .font(KorbiTheme.Typography.body(weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(settings.palette.primary)
                .disabled(isSubmittingItem || newItemName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private var categoryPicker: some View {
        Menu {
            ForEach(ItemCategory.allCases) { category in
                Button {
                    newItemCategory = category.rawValue
                } label: {
                    HStack {
                        Text(category.rawValue)
                        if newItemCategory == category.rawValue {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }

            if !newItemCategory.isEmpty {
                Divider()
                Button("Keine Kategorie") {
                    newItemCategory = ""
                }
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Kategorie")
                        .font(KorbiTheme.Typography.caption(weight: .semibold))
                        .foregroundStyle(settings.palette.textSecondary)

                    Text(newItemCategory.isEmpty ? "Kategorie wählen" : newItemCategory)
                        .font(KorbiTheme.Typography.body())
                        .foregroundStyle(
                            newItemCategory.isEmpty
                                ? settings.palette.textSecondary.opacity(0.85)
                                : settings.palette.textPrimary
                        )
                        .lineLimit(1)
                }

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

    private func submitManualItem() {
        guard !isSubmittingItem else { return }

        let trimmedName = newItemName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            itemErrorMessage = ItemCreationError.invalidName.errorDescription
            return
        }

        itemErrorMessage = nil
        isSubmittingItem = true

        Task {
            do {
                try await settings.addItem(
                    name: trimmedName,
                    description: newItemDescription,
                    quantity: newItemQuantity,
                    category: newItemCategory
                )

                await MainActor.run {
                    newItemName = ""
                    newItemDescription = ""
                    newItemQuantity = ""
                    newItemCategory = ""
                }
            } catch {
                let localizedError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                await MainActor.run {
                    itemErrorMessage = localizedError
                }
            }

            await MainActor.run {
                isSubmittingItem = false
            }
        }
    }

    private var todaysItems: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Heute zu besorgen")
                    .font(KorbiTheme.Typography.title())
                    .foregroundStyle(settings.palette.textPrimary)
                Button {
                    guard !isRefreshing else { return }
                    isRefreshing = true
                    Task {
                        await settings.refreshActiveSession()
                        await MainActor.run {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isRefreshing = false
                            }
                        }
                    }
                } label: {
                    if isRefreshing {
                        ProgressView()
                            .tint(settings.palette.primary)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .foregroundStyle(settings.palette.primary)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Aktualisieren")
                .disabled(isRefreshing)
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: cancelPendingCompletion)

            let items = settings.currentHouseholdItems
            if items.isEmpty {
                KorbiCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Noch keine Artikel geplant")
                            .font(KorbiTheme.Typography.body(weight: .semibold))
                            .foregroundStyle(settings.palette.textPrimary)
                        Text("Füge neue Produkte hinzu, damit dein Einkauf organisiert bleibt.")
                            .font(KorbiTheme.Typography.body())
                            .foregroundStyle(settings.palette.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                VStack(spacing: 16) {
                    ForEach(items) { item in
                        ItemRowView(
                            item: item,
                            state: completionState(for: item)
                        )
                        .onTapGesture {
                            handleItemTap(item)
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    pendingCompletionItemID = nil
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
                .padding(.vertical, 1)
            }
        }
    }

    private func completionState(for item: HouseholdItem) -> ItemRowView.CompletionState {
        if purchasedItems.contains(item.id) {
            return .confirmed
        }

        if pendingCompletionItemID == item.id {
            return .prompt
        }

        return .normal
    }

    private func handleItemTap(_ item: HouseholdItem) {
        if pendingCompletionItemID == item.id {
            confirmCompletion(for: item)
        } else {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                pendingCompletionItemID = item.id
            }
        }
    }

    private func confirmCompletion(for item: HouseholdItem) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            pendingCompletionItemID = nil
            purchasedItems.insert(item.id)
        }

        Task {
            await settings.markItemAsPurchased(item)
            _ = await MainActor.run {
                withAnimation(.easeInOut(duration: 0.25)) {
                    purchasedItems.remove(item.id)
                }
            }
        }
    }

    private func cancelPendingCompletion() {
        guard pendingCompletionItemID != nil else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            pendingCompletionItemID = nil
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(KorbiSettings())
        .environmentObject(AuthManager())
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    HomeView()
        .environmentObject(KorbiSettings())
        .environmentObject(AuthManager())
        .preferredColorScheme(.dark)
}
