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
    @Published private(set) var pendingInviteToken: String?

    private weak var settings: KorbiSettings?
    private weak var authManager: AuthManager?

    init(settings: KorbiSettings, authManager: AuthManager) {
        self.settings = settings
        self.authManager = authManager
    }

    func handleIncomingURL(_ url: URL) {
        guard let token = Self.extractToken(from: url) else { return }
        pendingInviteToken = token
        status = .pending(token: token)
        attemptProcessingIfPossible()
    }

    func attemptProcessingIfPossible() {
        guard let token = pendingInviteToken ?? status.token else { return }
        guard authManager?.isAuthenticated == true else { return }
        acceptInvite(with: token)
    }

    func retry() {
        guard let token = status.token ?? pendingInviteToken else { return }
        pendingInviteToken = token
        acceptInvite(with: token)
    }

    func clear() {
        status = .idle
        pendingInviteToken = nil
    }

    private func acceptInvite(with token: String) {
        guard let settings else { return }
        pendingInviteToken = token
        status = .processing(token: token)

        Task {
            do {
                let household = try await settings.acceptInvite(token: token)
                await MainActor.run {
                    pendingInviteToken = nil
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
        guard let token = components.queryItems?.first(where: { $0.name.lowercased() == "token" })?.value else {
            return nil
        }

        let scheme = components.scheme?.lowercased()
        let host = components.host?.lowercased()
        let path = components.path.lowercased()
        let absolute = url.absoluteString.lowercased()

        if scheme == "korbi", host == "invite" {
            return token
        }

        if let host, host.contains("korbiinvite") {
            return token
        }

        if path.contains("korbiinvite") || absolute.contains("korbiinvite") {
            return token
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
