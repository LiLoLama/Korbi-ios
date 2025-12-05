import SwiftUI

enum ListColorRole {
    case primary
    case accent
    case pantry
}

struct ShoppingListSummary: Identifiable {
    let id = UUID()
    let title: String
    let colorRole: ListColorRole
    let icon: String
}

struct ListsView: View {
    @EnvironmentObject private var settings: KorbiSettings
    @EnvironmentObject private var authManager: AuthManager
    private let lists: [ShoppingListSummary] = [
        .init(title: "Obst & Gemüse", colorRole: .primary, icon: "leaf.fill"),
        .init(title: "Backwaren & Frühstück", colorRole: .accent, icon: "bag.fill"),
        .init(title: "Milch & Kühlware", colorRole: .primary, icon: "drop.fill"),
        .init(title: "Vorrat & Konserven", colorRole: .pantry, icon: "shippingbox.fill"),
        .init(title: "Süßes & Snacks", colorRole: .accent, icon: "heart.fill"),
        .init(title: "Getränke", colorRole: .primary, icon: "wineglass.fill"),
        .init(title: "Tiefkühl", colorRole: .pantry, icon: "snowflake"),
        .init(title: "Drogerie & Körperpflege", colorRole: .accent, icon: "hand.raised.fill"),
        .init(title: "Haushalt & Reinigung", colorRole: .pantry, icon: "house.fill"),
        .init(title: "Tierbedarf", colorRole: .primary, icon: "pawprint.fill"),
        .init(title: "Baby & Kind", colorRole: .accent, icon: "person.2.fill"),
        .init(title: "Sonstiges", colorRole: .primary, icon: "ellipsis.circle")
    ]

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
