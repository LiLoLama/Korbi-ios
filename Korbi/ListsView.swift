import SwiftUI

struct ShoppingListSummary: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let itemsDue: Int
    let color: Color
    let icon: String
}

struct ListsView: View {
    private let lists: [ShoppingListSummary] = [
        .init(title: "Wocheneinkauf", subtitle: "Frische Zutaten für 4 Rezepte", itemsDue: 8, color: KorbiTheme.Colors.primary, icon: "basket.fill"),
        .init(title: "Haushalt Essentials", subtitle: "Nachfüllen & Vorräte prüfen", itemsDue: 5, color: KorbiTheme.Colors.accent, icon: "drop.degreeless.fill"),
        .init(title: "Vorratskammer", subtitle: "Lang haltbare Basics", itemsDue: 12, color: Color(red: 0.62, green: 0.53, blue: 0.39), icon: "cube.box.fill")
    ]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(lists) { list in
                        NavigationLink(destination: listDetail(list)) {
                            ListCard(summary: list)
                                .listRowInsets(EdgeInsets())
                        }
                        .listRowSeparator(.hidden)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {} label: {
                                Label("Delete", systemImage: "trash")
                            }
                            Button {} label: {
                                Label("Pin", systemImage: "pin")
                            }
                            .tint(list.color)
                        }
                    }
                } header: {
                    Text("Listen")
                        .font(KorbiTheme.Typography.title())
                        .foregroundStyle(KorbiTheme.Colors.textPrimary)
                        .padding(.bottom, 6)
                }
                .listRowBackground(Color.clear)
            }
            .scrollContentBackground(.hidden)
            .background(KorbiBackground())
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(KorbiTheme.Colors.background.opacity(0.9), for: .navigationBar)
            .navigationTitle("Listen")
        }
    }

    private func listDetail(_ summary: ShoppingListSummary) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(summary.title)
                .font(KorbiTheme.Typography.largeTitle())
            Text(summary.subtitle)
                .font(KorbiTheme.Typography.body())
                .foregroundStyle(KorbiTheme.Colors.textSecondary)
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(KorbiTheme.Colors.background)
    }
}

private struct ListCard: View {
    let summary: ShoppingListSummary

    var body: some View {
        KorbiCard {
            HStack(alignment: .center, spacing: 20) {
                ZStack {
                    RoundedRectangle(cornerRadius: KorbiTheme.Metrics.compactCornerRadius, style: .continuous)
                        .fill(summary.color.opacity(0.18))
                    Image(systemName: summary.icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(summary.color)
                }
                .frame(width: 58, height: 58)

                VStack(alignment: .leading, spacing: 10) {
                    Text(summary.title)
                        .font(KorbiTheme.Typography.body(weight: .semibold))
                        .foregroundStyle(KorbiTheme.Colors.textPrimary)
                    Text(summary.subtitle)
                        .font(KorbiTheme.Typography.body())
                        .foregroundStyle(KorbiTheme.Colors.textSecondary)

                    HStack(spacing: 10) {
                        PillTag(text: "\(summary.itemsDue) offen", systemImage: "clock")
                        PillTag(text: "Teilen", systemImage: "person.2")
                    }
                }
                Spacer()
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ListsView()
}
