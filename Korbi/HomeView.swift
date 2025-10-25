import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var settings: KorbiSettings
    @State private var showRecentPurchases = false
    @State private var purchasedItems: Set<UUID> = []
    @State private var itemPendingConfirmationID: UUID?
    @State private var itemDeletingID: UUID?
    @State private var suppressBackgroundTapReset = false

    var body: some View {
        NavigationStack {
            ZStack {
                KorbiBackground()
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            itemPendingConfirmationID = nil
                        }
                    }

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
                .refreshable {
                    await settings.refreshActiveSession()
                }
                .simultaneousGesture(
                    TapGesture().onEnded {
                        if suppressBackgroundTapReset {
                            suppressBackgroundTapReset = false
                        } else {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                itemPendingConfirmationID = nil
                            }
                        }
                    }
                )
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
        .onChange(of: settings.currentHouseholdItems) { newItems in
            let validIDs = Set(newItems.map { $0.id })
            if let pendingID = itemPendingConfirmationID, !validIDs.contains(pendingID) {
                itemPendingConfirmationID = nil
            }
            if let deletingID = itemDeletingID, !validIDs.contains(deletingID) {
                itemDeletingID = nil
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
                            isPurchased: purchasedItems.contains(item.id)
                        )
                        .overlay { confirmationOverlay(for: item) }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            handleItemTap(item)
                        }
                        .purchaseCelebration(isActive: purchasedItems.contains(item.id))
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
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
}

#Preview {
    HomeView()
        .environmentObject(KorbiSettings())
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    HomeView()
        .environmentObject(KorbiSettings())
        .preferredColorScheme(.dark)
}

extension HomeView {
    @ViewBuilder
    private func confirmationOverlay(for item: HouseholdItem) -> some View {
        if itemDeletingID == item.id {
            overlayView(
                background: Color.green,
                foregroundColor: .white,
                title: "Erledigt",
                systemImage: "checkmark.circle.fill"
            )
        } else if itemPendingConfirmationID == item.id {
            overlayView(
                background: Color.green.opacity(0.25),
                foregroundColor: settings.palette.textPrimary,
                title: "Erledigt?",
                systemImage: "hand.tap.fill"
            )
        }
    }

    private func overlayView(background: Color, foregroundColor: Color, title: String, systemImage: String) -> some View {
        RoundedRectangle(cornerRadius: KorbiTheme.Metrics.compactCornerRadius, style: .continuous)
            .fill(background)
            .overlay {
                HStack(spacing: 12) {
                    Image(systemName: systemImage)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(foregroundColor)
                    Text(title)
                        .font(KorbiTheme.Typography.body(weight: .semibold))
                        .foregroundStyle(foregroundColor)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
            }
            .transition(.opacity)
            .allowsHitTesting(false)
    }

    private func handleItemTap(_ item: HouseholdItem) {
        suppressBackgroundTapReset = true
        DispatchQueue.main.async {
            suppressBackgroundTapReset = false
        }

        if itemDeletingID != nil {
            return
        }

        if itemPendingConfirmationID == item.id {
            withAnimation(.easeInOut(duration: 0.2)) {
                itemDeletingID = item.id
            }
            itemPendingConfirmationID = nil

            Task {
                try? await Task.sleep(nanoseconds: 180_000_000)
                await settings.markItemAsPurchased(item)
                await MainActor.run {
                    if itemDeletingID == item.id {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            itemDeletingID = nil
                        }
                    }
                }
            }
        } else {
            withAnimation(.easeInOut(duration: 0.2)) {
                itemPendingConfirmationID = item.id
            }
        }
    }
}
