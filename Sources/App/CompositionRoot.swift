import SwiftUI

@MainActor
final class CompositionRoot: ObservableObject {
    enum AppTheme: String, CaseIterable, Identifiable {
        case system
        case light
        case dark

        var id: String { rawValue }

        var label: String {
            switch self {
            case .system: return "System"
            case .light: return "Hell"
            case .dark: return "Dunkel"
            }
        }

        var colorScheme: ColorScheme? {
            switch self {
            case .system: return nil
            case .light: return .light
            case .dark: return .dark
            }
        }
    }

    @Published var theme: AppTheme = .system

    let householdService: HouseholdServicing
    let listsService: ListsServicing
    let itemsService: ItemsServicing

    init(
        householdService: HouseholdServicing = HouseholdFakeService(),
        listsService: ListsServicing = ListsFakeService(),
        itemsService: ItemsServicing = ItemsFakeService()
    ) {
        self.householdService = householdService
        self.listsService = listsService
        self.itemsService = itemsService
    }
}

struct RootView: View {
    @EnvironmentObject private var root: CompositionRoot

    var body: some View {
        TabView {
            HomeView(viewModel: HomeViewModel(
                householdService: root.householdService,
                listsService: root.listsService,
                itemsService: root.itemsService
            ))
            .tabItem { Label("Home", systemImage: "house") }

            ListsView(viewModel: ListViewModel(
                listsService: root.listsService,
                itemsService: root.itemsService
            ))
            .tabItem { Label("Listen", systemImage: "list.bullet") }

            HouseholdView(viewModel: HouseholdViewModel(service: root.householdService))
                .tabItem { Label("Haushalt", systemImage: "person.2") }

            SettingsView(viewModel: SettingsViewModel(root: root))
                .tabItem { Label("Einstellungen", systemImage: "gear") }
        }
        .tint(Tokens.tintPrimary)
        .background(Tokens.bgPrimary)
        .preferredColorScheme(root.theme.colorScheme)
    }
}
