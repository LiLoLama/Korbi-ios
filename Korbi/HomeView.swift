import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var settings: KorbiSettings
    @EnvironmentObject private var authManager: AuthManager
    @State private var showRecentPurchases = false
    @State private var purchasedItems: Set<UUID> = []
    @State private var pendingCompletionItemID: UUID?
    @State private var isRefreshing = false

    var body: some View {
        NavigationStack {
            ZStack {
                KorbiBackground()
                    .contentShape(Rectangle())
                    .onTapGesture(perform: cancelPendingCompletion)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 28) {
                        if !settings.recentPurchases.isEmpty {
                            recentPurchasesButton
                        }
                        todaysItems
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                }
                .onChange(of: settings.currentHouseholdItems) { items in
                    guard let pendingID = pendingCompletionItemID else { return }
                    if !items.contains(where: { $0.id == pendingID }) {
                        pendingCompletionItemID = nil
                    }
                }
                .safeAreaInset(edge: .bottom) {
                    FloatingMicButton()
                        .padding(.top, 16)
                        .padding(.bottom, 24)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(settings.palette.background.opacity(0.85), for: .navigationBar)
            .navigationTitle("Korbi")
            .navigationBarTitleDisplayMode(.large)
        }
        .accentColor(settings.palette.primary)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
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
                .accessibilityLabel("Aktualisieren")
                .disabled(isRefreshing)
            }
        }
        .sheet(isPresented: $showRecentPurchases) {
            NavigationStack {
                List {
                    if settings.recentPurchases.isEmpty {
                        Text("Keine Einkäufe vorhanden.")
                            .font(KorbiTheme.Typography.body())
                            .foregroundStyle(settings.palette.textSecondary)
                    } else {
                        ForEach(Array(settings.recentPurchases.prefix(10)), id: \.self) { item in
                            Label(item, systemImage: "checkmark.circle")
                                .foregroundStyle(settings.palette.primary)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .background(settings.palette.background)
                .navigationTitle("Kürzlich gekauft")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Fertig") { showRecentPurchases = false }
                            .foregroundStyle(settings.palette.primary)
                    }
                }
            }
            .environmentObject(settings)
        }
    }

    private var recentPurchasesButton: some View {
        Button(action: { showRecentPurchases = true }) {
            Label("Kürzlich gekauft", systemImage: "clock.arrow.circlepath")
                .font(KorbiTheme.Typography.body(weight: .semibold))
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(settings.palette.primary.opacity(0.9))
        .controlSize(.large)
        .clipShape(RoundedRectangle(cornerRadius: KorbiTheme.Metrics.compactCornerRadius, style: .continuous))
    }

    private var todaysItems: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Heute zu besorgen")
                    .font(KorbiTheme.Typography.title())
                    .foregroundStyle(settings.palette.textPrimary)
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
                                    await MainActor.run {
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
            await MainActor.run {
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
