import SwiftUI

enum ListColorRole {
    case primary
    case accent
    case pantry
}

struct ListItem: Identifiable {
    let id: UUID
    let name: String
    let description: String
    let quantity: String
}

struct CategorySummary: Identifiable {
    let id = UUID()
    let title: String
    let colorRole: ListColorRole
    let icon: String
    let items: [ListItem]
}

struct ListsView: View {
    @EnvironmentObject private var settings: KorbiSettings
    @EnvironmentObject private var authManager: AuthManager
    @State private var categories: [CategorySummary] = []
    @State private var loadError: String?

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                KorbiBackground()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        if let loadError {
                            Text(loadError)
                                .font(KorbiTheme.Typography.caption())
                                .foregroundStyle(Color.red)
                        }
                        LazyVStack(spacing: 20) {
                            ForEach(categories) { list in
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
        .task {
            await loadCategories()
        }
    }

    private func loadCategories() async {
        do {
            let supabaseItems = try await authManager.fetchItems()
            let grouped = Dictionary(grouping: supabaseItems) { item in
                let trimmed = item.category?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                return trimmed.isEmpty ? "Sonstiges" : trimmed
            }
            let sortedKeys = grouped.keys.sorted { lhs, rhs in
                lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
            }
            let summaries = sortedKeys.enumerated().map { index, key -> CategorySummary in
                let items = grouped[key] ?? []
                let mappedItems = items.map { item in
                    ListItem(
                        id: item.id ?? UUID(),
                        name: item.name,
                        description: item.description ?? "",
                        quantity: item.quantity?.isEmpty == false ? item.quantity! : "1"
                    )
                }
                return CategorySummary(
                    title: key,
                    colorRole: colorRole(for: index),
                    icon: iconName(for: key),
                    items: mappedItems
                )
            }
            await MainActor.run {
                categories = summaries
                loadError = summaries.isEmpty ? "Keine Listen gefunden." : nil
            }
        } catch {
            await MainActor.run {
                categories = []
                loadError = "Listen konnten nicht geladen werden."
            }
        }
    }

    private func colorRole(for index: Int) -> ListColorRole {
        switch index % 3 {
        case 0: return .primary
        case 1: return .accent
        default: return .pantry
        }
    }

    private func iconName(for category: String) -> String {
        let mapping: [String: String] = [
            "Obst & Gemüse": "leaf.fill",
            "Backwaren": "bag.fill",
            "Backwaren & Frühstück": "bag.fill",
            "Milch & Kühlware": "drop.fill",
            "Vorrat & Konserven": "shippingbox.fill",
            "Süßes & Snacks": "heart.fill",
            "Getränke": "wineglass.fill",
            "Tiefkühl": "snowflake",
            "Drogerie & Körperpflege": "hand.raised.fill",
            "Haushalt & Reinigung": "house.fill",
            "Tierbedarf": "pawprint.fill",
            "Baby & Kind": "person.2.fill",
            "Sonstiges": "ellipsis.circle"
        ]

        if let icon = mapping[category] {
            return icon
        }

        if category.localizedCaseInsensitiveContains("obst") || category.localizedCaseInsensitiveContains("gemüse") {
            return "leaf.fill"
        }
        if category.localizedCaseInsensitiveContains("getränk") {
            return "wineglass.fill"
        }
        if category.localizedCaseInsensitiveContains("haushalt") {
            return "house.fill"
        }
        return "cart.fill"
    }

    private func listDetail(_ summary: CategorySummary) -> some View {
        List {
            ForEach(summary.items) { item in
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.name)
                        .font(KorbiTheme.Typography.body(weight: .semibold))
                    if !item.description.isEmpty {
                        Text(item.description)
                            .font(KorbiTheme.Typography.caption())
                            .foregroundStyle(settings.palette.textSecondary)
                    }
                    Text("Menge: \(item.quantity)")
                        .font(KorbiTheme.Typography.caption())
                        .foregroundStyle(settings.palette.primary.opacity(0.75))
                }
                .padding(.vertical, 8)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(settings.palette.background)
        .navigationTitle(summary.title)
    }
}

private struct ListCard: View {
    @EnvironmentObject private var settings: KorbiSettings
    let summary: CategorySummary

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
                Spacer()
                Text("\(summary.items.count)")
                    .font(KorbiTheme.Typography.caption(weight: .semibold))
                    .foregroundStyle(settings.palette.primary.opacity(0.75))
                Image(systemName: "chevron.right")
                    .foregroundStyle(settings.palette.primary.opacity(0.7))
            }
        }
        .padding(.vertical, 4)
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
