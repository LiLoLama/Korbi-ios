import SwiftUI

enum ListColorRole {
    case primary
    case accent
    case pantry
}

struct ShoppingListSummary: Identifiable {
    let id = UUID()
    let title: String
    let itemsDue: Int
    let colorRole: ListColorRole
    let icon: String
}

struct ListsView: View {
    @EnvironmentObject private var settings: KorbiSettings

    private let lists: [ShoppingListSummary] = [
        .init(title: "Wocheneinkauf", itemsDue: 8, colorRole: .primary, icon: "basket.fill"),
        .init(title: "Haushalt Essentials", itemsDue: 5, colorRole: .accent, icon: "drop.degreeless.fill"),
        .init(title: "Vorratskammer", itemsDue: 12, colorRole: .pantry, icon: "cube.box.fill")
    ]

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                KorbiBackground()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        Text("Listen")
                            .font(KorbiTheme.Typography.title())
                            .foregroundStyle(settings.palette.textPrimary)

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
                    .padding(.bottom, 140)
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                } label: {
                    Label("Eigene Liste erstellen", systemImage: "plus.circle.fill")
                        .font(KorbiTheme.Typography.body(weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.plain)
                .background(settings.palette.primary)
                .foregroundStyle(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: KorbiTheme.Metrics.defaultCornerRadius, style: .continuous))
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
                .shadow(color: settings.palette.primary.opacity(0.2), radius: 12, y: 4)
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
            PillTag(text: "\(summary.itemsDue) offen", systemImage: "clock")
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

                VStack(alignment: .leading, spacing: 10) {
                    Text(summary.title)
                        .font(KorbiTheme.Typography.body(weight: .semibold))
                        .foregroundStyle(settings.palette.textPrimary)

                    PillTag(text: "\(summary.itemsDue) offen", systemImage: "clock")
                }
                Spacer()
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
