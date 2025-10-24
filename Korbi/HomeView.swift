import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var settings: KorbiSettings
    @State private var showRecentPurchases = false

    var body: some View {
        NavigationStack {
            ZStack {
                KorbiBackground()

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
                        KorbiCard {
                            HStack(alignment: .center, spacing: 16) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(item.name)
                                        .font(KorbiTheme.Typography.body(weight: .semibold))
                                        .foregroundStyle(settings.palette.textPrimary)
                                    if !item.quantity.isEmpty {
                                        Text(item.quantity)
                                            .font(KorbiTheme.Typography.caption())
                                            .foregroundStyle(settings.palette.primary.opacity(0.75))
                                    }
                                    if !item.description.isEmpty {
                                        Text(item.description)
                                            .font(KorbiTheme.Typography.body())
                                            .foregroundStyle(settings.palette.textSecondary)
                                            .lineLimit(2)
                                    }
                                }
                                Spacer()
                            }
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
