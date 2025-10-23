import SwiftUI

struct ShoppingItem: Identifiable {
    let id = UUID()
    let name: String
    let quantity: String
    let note: String
    let isUrgent: Bool
}

struct HomeView: View {
    @EnvironmentObject private var settings: KorbiSettings
    @State private var showRecentPurchases = false

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
                        recentPurchasesButton
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
            .toolbarBackground(settings.palette.background.opacity(0.85), for: .navigationBar)
            .navigationTitle("Korbi")
            .navigationBarTitleDisplayMode(.large)
        }
        .accentColor(settings.palette.primary)
        .sheet(isPresented: $showRecentPurchases) {
            NavigationStack {
                List {
                    ForEach(Array(settings.recentPurchases.prefix(10)), id: \.self) { item in
                        Label(item, systemImage: "checkmark.circle")
                            .foregroundStyle(settings.palette.primary)
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
                Spacer()
                Button("Alle anzeigen") {}
                    .font(KorbiTheme.Typography.body(weight: .medium))
                    .foregroundStyle(settings.palette.primary)
            }

            VStack(spacing: 16) {
                ForEach(todayItems) { item in
                    KorbiCard {
                        HStack(alignment: .top, spacing: 16) {
                            ZStack {
                                RoundedRectangle(cornerRadius: KorbiTheme.Metrics.compactCornerRadius, style: .continuous)
                                    .fill(settings.palette.primary.opacity(0.14))
                                Image(systemName: item.isUrgent ? "leaf.fill" : "bag")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(settings.palette.primary)
                            }
                            .frame(width: 56, height: 56)

                            VStack(alignment: .leading, spacing: 8) {
                                Text(item.name)
                                    .font(KorbiTheme.Typography.body(weight: .semibold))
                                    .foregroundStyle(settings.palette.textPrimary)
                                Text(item.quantity)
                                    .font(KorbiTheme.Typography.caption())
                                    .foregroundStyle(settings.palette.primary.opacity(0.75))
                                Text(item.note)
                                    .font(KorbiTheme.Typography.body())
                                    .foregroundStyle(settings.palette.textSecondary)
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
        .environmentObject(KorbiSettings())
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    HomeView()
        .environmentObject(KorbiSettings())
        .preferredColorScheme(.dark)
}
