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
            List {
                Section {
                    Button {
                    } label: {
                        Label("Eigene Liste erstellen", systemImage: "plus.circle.fill")
                            .font(KorbiTheme.Typography.body(weight: .semibold))
                            .foregroundStyle(settings.palette.primary)
                    }
                    .listRowBackground(Color.clear)
                }

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
                            .tint(color(for: list.colorRole))
                        }
                    }
                } header: {
                    Text("Listen")
                        .font(KorbiTheme.Typography.title())
                        .foregroundStyle(settings.palette.textPrimary)
                        .padding(.bottom, 6)
                }
                .listRowBackground(Color.clear)
            }
            .scrollContentBackground(.hidden)
            .background(KorbiBackground())
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

    private func color(for role: ListColorRole) -> Color {
        switch role {
        case .primary:
            return settings.palette.primary
        case .accent:
            return settings.palette.accent
        case .pantry:
            return Color(red: 0.62, green: 0.53, blue: 0.39)
        }
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
