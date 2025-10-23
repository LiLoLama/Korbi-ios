import Foundation
import SwiftUI

extension Notification.Name {
    static let debugSimulateEmptyState = Notification.Name("debugSimulateEmptyState")
    static let debugShowErrorBanner = Notification.Name("debugShowErrorBanner")
    static let debugShowLoadingBanner = Notification.Name("debugShowLoadingBanner")
}

extension View {
    func embedInNavigation() -> some View {
        NavigationStack { self }
    }
}
