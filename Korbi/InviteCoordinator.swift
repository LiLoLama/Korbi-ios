import Foundation
import SwiftUI

@MainActor
final class InviteCoordinator: ObservableObject {
    enum Status: Equatable {
        case idle
        case pending(token: String)
        case processing(token: String)
        case success(householdName: String?)
        case failure(message: String, token: String)

        var token: String? {
            switch self {
            case let .pending(token), let .processing(token), let .failure(_, token):
                return token
            default:
                return nil
            }
        }

        var isProcessing: Bool {
            if case .processing = self { return true }
            return false
        }
    }

    @Published private(set) var status: Status = .idle

    private weak var settings: KorbiSettings?
    private weak var authManager: AuthManager?

    init(settings: KorbiSettings, authManager: AuthManager) {
        self.settings = settings
        self.authManager = authManager
    }

    func handleIncomingURL(_ url: URL) {
        guard let token = Self.extractToken(from: url) else { return }
        status = .pending(token: token)
        attemptProcessingIfPossible()
    }

    func attemptProcessingIfPossible() {
        guard let token = status.token else { return }
        guard authManager?.isAuthenticated == true else { return }
        acceptInvite(with: token)
    }

    func retry() {
        guard let token = status.token else { return }
        acceptInvite(with: token)
    }

    func clear() {
        status = .idle
    }

    private func acceptInvite(with token: String) {
        guard let settings else { return }
        status = .processing(token: token)

        Task {
            do {
                let household = try await settings.acceptInvite(token: token)
                await MainActor.run {
                    status = .success(householdName: household?.name)
                }
            } catch {
                let message = Self.map(error: error)
                await MainActor.run {
                    status = .failure(message: message, token: token)
                }
            }
        }
    }

    private static func extractToken(from url: URL) -> String? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        if let host = components.host,
           host.lowercased().contains("korbiinvite"),
           let tokenQuery = components.queryItems?.first(where: { $0.name == "token" })?.value {
            return tokenQuery
        }

        if components.path.lowercased().contains("korbiinvite") ||
            url.absoluteString.lowercased().contains("korbiinvite"),
           let tokenQuery = components.queryItems?.first(where: { $0.name == "token" })?.value {
            return tokenQuery
        }

        return nil
    }

    private static func map(error: Error) -> String {
        if let inviteError = error as? InviteError {
            return inviteError.localizedDescription ?? "Die Einladung konnte nicht angenommen werden."
        }
        if let supabaseError = error as? SupabaseError {
            return supabaseError.localizedDescription ?? "Die Einladung konnte nicht angenommen werden."
        }
        return error.localizedDescription
    }
}

struct InviteAlert: Identifiable, Equatable {
    enum Kind {
        case success(message: String)
        case failure(message: String)
    }

    let id = UUID()
    let title: String
    let message: String
    let kind: Kind

    static func == (lhs: InviteAlert, rhs: InviteAlert) -> Bool {
        lhs.id == rhs.id
    }
}
