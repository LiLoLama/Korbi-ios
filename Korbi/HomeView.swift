import SwiftUI

struct ShoppingItem: Identifiable {
    let id: UUID
    let name: String
    let quantity: String
    let note: String
    let isUrgent: Bool
}

struct HomeView: View {
    @EnvironmentObject private var settings: KorbiSettings
    @EnvironmentObject private var authManager: AuthManager
    @State private var showRecentPurchases = false
    @State private var todayItems: [ShoppingItem] = []
    @State private var fetchError: String?

    var body: some View {
        NavigationStack {
            ZStack {
                KorbiBackground()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 28) {
                        if !settings.recentPurchases.isEmpty {
                            recentPurchasesButton
                        }
                        if let fetchError {
                            Text(fetchError)
                                .font(KorbiTheme.Typography.caption())
                                .foregroundStyle(Color.red)
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
        .task {
            await loadItems()
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

    private func loadItems() async {
        do {
            let supabaseItems = try await authManager.fetchItems()
            let mappedItems = supabaseItems.map { item in
                ShoppingItem(
                    id: item.id ?? UUID(),
                    name: item.name,
                    quantity: item.quantity?.isEmpty == false ? item.quantity! : "1",
                    note: item.description ?? "",
                    isUrgent: (item.category ?? "").localizedCaseInsensitiveContains("frisch")
                )
            }
            await MainActor.run {
                todayItems = mappedItems
                fetchError = nil
            }
        } catch {
            await MainActor.run {
                todayItems = []
                fetchError = "Artikel konnten nicht geladen werden."
            }
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

            if todayItems.isEmpty {
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
                    ForEach(todayItems) { item in
                        KorbiCard {
                            HStack(alignment: .center, spacing: 16) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(item.name)
                                        .font(KorbiTheme.Typography.body(weight: .semibold))
                                        .foregroundStyle(settings.palette.textPrimary)
                                    Text(item.quantity)
                                        .font(KorbiTheme.Typography.caption())
                                        .foregroundStyle(settings.palette.primary.opacity(0.75))
                                    if !item.note.isEmpty {
                                        Text(item.note)
                                            .font(KorbiTheme.Typography.caption())
                                            .foregroundStyle(settings.palette.textSecondary)
                                            .lineLimit(2)
                                    }
                                }
                                Spacer()

                                if item.isUrgent {
                                    PillTag(text: "Frisch", systemImage: "sun.max")
                                }
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
        .environmentObject(AuthManager())
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    HomeView()
        .environmentObject(KorbiSettings())
        .environmentObject(AuthManager())
        .preferredColorScheme(.dark)
}
