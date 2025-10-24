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
        VStack(alignment: .leading, spacing: 16) {
            Text(summary.title)
                .font(KorbiTheme.Typography.largeTitle())
                .foregroundStyle(settings.palette.textPrimary)
            Text("Lege Artikel in dieser Kategorie an, um den Überblick zu behalten.")
                .font(KorbiTheme.Typography.body())
                .foregroundStyle(settings.palette.textSecondary)
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(settings.palette.background)
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
                Spacer()
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
}
