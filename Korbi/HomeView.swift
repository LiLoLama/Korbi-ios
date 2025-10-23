import SwiftUI

struct ShoppingItem: Identifiable {
    let id = UUID()
    let name: String
    let quantity: String
    let note: String
    let isUrgent: Bool
}

struct HomeView: View {
    private let todayItems: [ShoppingItem] = [
        .init(name: "Seasonal greens", quantity: "1 bundle", note: "Farmer's market – local", isUrgent: true),
        .init(name: "Oat milk", quantity: "2 cartons", note: "Barista blend for mornings", isUrgent: false),
        .init(name: "Dish tablets", quantity: "1 box", note: "Eco refill pack", isUrgent: false)
    ]

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                KorbiBackground()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 28) {
                        greeting
                        focusCard
                        todaysItems
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, 120)
                }

                FloatingMicButton()
                    .padding(.bottom, 40)
            }
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(KorbiTheme.Colors.background.opacity(0.85), for: .navigationBar)
            .navigationTitle("Korbi")
            .navigationBarTitleDisplayMode(.large)
        }
        .accentColor(KorbiTheme.Colors.primary)
    }

    private var greeting: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Hi Korbi Crew")
                .font(KorbiTheme.Typography.title())
                .foregroundStyle(KorbiTheme.Colors.textSecondary)
            Text("Heute im Blick")
                .font(KorbiTheme.Typography.largeTitle())
                .foregroundStyle(KorbiTheme.Colors.textPrimary)
        }
    }

    private var focusCard: some View {
        KorbiCard {
            VStack(alignment: .leading, spacing: 16) {
                PillTag(text: "Frische Woche", systemImage: "leaf")
                Text("Fridge check & restock")
                    .font(KorbiTheme.Typography.title())
                    .foregroundStyle(KorbiTheme.Colors.textPrimary)
                Text("Korbi schlägt eine ausgewogene Mischung aus frischen Zutaten und Haushaltsbasics vor. Lass uns gemeinsam beginnen.")
                    .font(KorbiTheme.Typography.body())
                    .foregroundStyle(KorbiTheme.Colors.textSecondary)
                Divider()
                    .overlay(KorbiTheme.Colors.outline.opacity(0.4))
                HStack(spacing: 16) {
                    Label("3 neue Inspirationen", systemImage: "sparkles")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(KorbiTheme.Colors.primary)
                }
                .font(KorbiTheme.Typography.body(weight: .medium))
                .foregroundStyle(KorbiTheme.Colors.primary)
            }
        }
    }

    private var todaysItems: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Heute zu besorgen")
                    .font(KorbiTheme.Typography.title())
                    .foregroundStyle(KorbiTheme.Colors.textPrimary)
                Spacer()
                Button("Alle anzeigen") {}
                    .font(KorbiTheme.Typography.body(weight: .medium))
                    .foregroundStyle(KorbiTheme.Colors.primary)
            }

            VStack(spacing: 16) {
                ForEach(todayItems) { item in
                    KorbiCard {
                        HStack(alignment: .top, spacing: 16) {
                            ZStack {
                                RoundedRectangle(cornerRadius: KorbiTheme.Metrics.compactCornerRadius, style: .continuous)
                                    .fill(KorbiTheme.Colors.primary.opacity(0.14))
                                Image(systemName: item.isUrgent ? "leaf.fill" : "bag")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(KorbiTheme.Colors.primary)
                            }
                            .frame(width: 56, height: 56)

                            VStack(alignment: .leading, spacing: 8) {
                                Text(item.name)
                                    .font(KorbiTheme.Typography.body(weight: .semibold))
                                    .foregroundStyle(KorbiTheme.Colors.textPrimary)
                                Text(item.quantity)
                                    .font(KorbiTheme.Typography.caption())
                                    .foregroundStyle(KorbiTheme.Colors.primary.opacity(0.75))
                                Text(item.note)
                                    .font(KorbiTheme.Typography.body())
                                    .foregroundStyle(KorbiTheme.Colors.textSecondary)
                            }
                            Spacer()

                            if item.isUrgent {
                                PillTag(text: "Frisch", systemImage: "sun.max")
                            }
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    HomeView()
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    HomeView()
        .preferredColorScheme(.dark)
}
