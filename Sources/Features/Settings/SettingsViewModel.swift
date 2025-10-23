import Foundation

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var selectedTheme: CompositionRoot.AppTheme
    @Published var simulateEmptyState: Bool = false {
        didSet {
            NotificationCenter.default.post(name: .debugSimulateEmptyState, object: nil)
        }
    }

    private unowned let root: CompositionRoot

    init(root: CompositionRoot) {
        self.root = root
        self.selectedTheme = root.theme
    }

    func updateTheme(_ theme: CompositionRoot.AppTheme) {
        selectedTheme = theme
        root.theme = theme
    }

    func triggerErrorBanner() {
        NotificationCenter.default.post(name: .debugShowErrorBanner, object: nil)
    }

    func triggerLoadingBanner() {
        NotificationCenter.default.post(name: .debugShowLoadingBanner, object: nil)
    }
}
