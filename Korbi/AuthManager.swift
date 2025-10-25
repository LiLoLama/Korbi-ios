import Foundation
import SwiftUI

enum AuthError: LocalizedError, Equatable {
    case invalidEmail
    case passwordTooShort
    case passwordsDoNotMatch
    case emailAlreadyRegistered
    case invalidCredentials
    case missingConfiguration

    var errorDescription: String? {
        switch self {
        case .invalidEmail:
            return "Bitte gib eine gültige E-Mail-Adresse ein."
        case .passwordTooShort:
            return "Das Passwort muss mindestens 6 Zeichen lang sein."
        case .passwordsDoNotMatch:
            return "Die Passwörter stimmen nicht überein."
        case .emailAlreadyRegistered:
            return "Diese E-Mail-Adresse ist bereits registriert."
        case .invalidCredentials:
            return "Die Zugangsdaten sind nicht korrekt."
        case .missingConfiguration:
            return "Supabase ist nicht konfiguriert."
        }
    }
}

@MainActor
final class AuthManager: ObservableObject {
    @Published private(set) var isAuthenticated: Bool = false
    @Published private(set) var currentUserEmail: String? = nil

    private struct StoredSession: Codable, Equatable {
        let accessToken: String
        let refreshToken: String?
        let userID: UUID
        let email: String
        let primaryHouseholdID: UUID
        let accessTokenExpiresAt: Date?

        init(session: SupabaseAuthSession, primaryHouseholdID: UUID = UUID(), fallbackEmail: String) {
            self.accessToken = session.accessToken
            self.refreshToken = session.refreshToken
            self.userID = session.userID
            self.email = session.email.isEmpty ? fallbackEmail : session.email
            self.primaryHouseholdID = primaryHouseholdID
            self.accessTokenExpiresAt = session.expiresAt
        }
    }

    private let userDefaults: UserDefaults
    private let supabaseClient: SupabaseService
    private let storedSessionKey = "korbi.auth.session"
    private let tokenRefreshLeeway: TimeInterval = 300

    private var storedSession: StoredSession? {
        didSet { persistSession() }
    }

    @Published private(set) var session: SupabaseAuthSession?
    private var refreshTask: Task<Void, Never>?

    init(
        userDefaults: UserDefaults = .standard,
        supabaseClient: SupabaseService = SupabaseClient()
    ) {
        self.userDefaults = userDefaults
        self.supabaseClient = supabaseClient

        if let data = userDefaults.data(forKey: storedSessionKey),
           let storedSession = try? JSONDecoder().decode(StoredSession.self, from: data) {
            self.storedSession = storedSession
            currentUserEmail = storedSession.email
            isAuthenticated = true
            session = SupabaseAuthSession(
                accessToken: storedSession.accessToken,
                refreshToken: storedSession.refreshToken,
                userID: storedSession.userID,
                email: storedSession.email,
                expiresAt: storedSession.accessTokenExpiresAt
            )
        } else {
            storedSession = nil
            currentUserEmail = nil
            isAuthenticated = false
            session = nil
        }

        if let session {
            scheduleRefresh(for: session)
            Task { @MainActor [weak self] in
                try? await self?.refreshSessionIfNeeded()
            }
        }
    }

    func login(email: String, password: String) async throws {
        let normalizedEmail = normalize(email)
        guard isValidEmail(normalizedEmail) else { throw AuthError.invalidEmail }

        do {
            let session = try await supabaseClient.signIn(email: normalizedEmail, password: password)
            let storedSession = StoredSession(
                session: session,
                primaryHouseholdID: existingHouseholdID(for: session),
                fallbackEmail: normalizedEmail
            )
            self.storedSession = storedSession
            currentUserEmail = storedSession.email
            isAuthenticated = true
            self.session = session
            scheduleRefresh(for: session)
        } catch let error as SupabaseError {
            throw mapSupabaseError(error)
        } catch {
            throw error
        }
    }

    func register(email: String, password: String, confirmation: String) async throws {
        let normalizedEmail = normalize(email)

        guard isValidEmail(normalizedEmail) else { throw AuthError.invalidEmail }
        guard password.count >= 6 else { throw AuthError.passwordTooShort }
        guard password == confirmation else { throw AuthError.passwordsDoNotMatch }

        do {
            _ = try await supabaseClient.signUp(email: normalizedEmail, password: password)
        } catch let error as SupabaseError {
            throw mapSupabaseError(error)
        }
    }

    func logout() {
        refreshTask?.cancel()
        refreshTask = nil
        isAuthenticated = false
        currentUserEmail = nil
        storedSession = nil
        userDefaults.removeObject(forKey: storedSessionKey)
        session = nil
    }

    func getValidSession() async throws -> SupabaseAuthSession {
        try await refreshSessionIfNeeded()
        if let session {
            return session
        }

        if let storedSession {
            let restoredSession = SupabaseAuthSession(
                accessToken: storedSession.accessToken,
                refreshToken: storedSession.refreshToken,
                userID: storedSession.userID,
                email: storedSession.email,
                expiresAt: storedSession.accessTokenExpiresAt
            )
            self.session = restoredSession
            scheduleRefresh(for: restoredSession)
            return restoredSession
        }

        throw AuthError.invalidCredentials
    }

    func refreshSessionIfNeeded() async throws {
        guard shouldRefreshSession() else { return }
        try await refreshSession()
    }

    func refreshSession() async throws {
        guard let storedSession, let currentRefreshToken = storedSession.refreshToken else {
            logout()
            throw AuthError.invalidCredentials
        }

        do {
            let newSession = try await supabaseClient.refreshToken(refreshToken: currentRefreshToken)

            let updatedStoredSession = StoredSession(
                session: newSession,
                primaryHouseholdID: storedSession.primaryHouseholdID,
                fallbackEmail: storedSession.email
            )

            self.storedSession = updatedStoredSession
            self.session = newSession
            self.isAuthenticated = true
            self.currentUserEmail = newSession.email
            scheduleRefresh(for: newSession)

        } catch {
            logout()
            throw error
        }
    }

    func performAuthenticatedRequest<T>(request: @escaping (String) async throws -> T) async throws -> T {
        let session = try await getValidSession()

        do {
            return try await request(session.accessToken)
        } catch let error as SupabaseError {
            if case let .requestFailed(statusCode, _) = error, statusCode == 401 {
                try await refreshSession()
                let refreshedSession = try await getValidSession()
                return try await request(refreshedSession.accessToken)
            }
            throw error
        } catch {
            throw error
        }
    }

    private func persistSession() {
        guard let storedSession else {
            userDefaults.removeObject(forKey: storedSessionKey)
            return
        }

        if let data = try? JSONEncoder().encode(storedSession) {
            userDefaults.set(data, forKey: storedSessionKey)
        }
    }

    private func normalize(_ email: String) -> String {
        return email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func isValidEmail(_ email: String) -> Bool {
        let pattern = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
        let predicate = NSPredicate(format: "SELF MATCHES %@", pattern)
        return predicate.evaluate(with: email)
    }

    private func existingHouseholdID(for session: SupabaseAuthSession) -> UUID {
        if let storedSession,
           storedSession.userID == session.userID {
            return storedSession.primaryHouseholdID
        }

        return UUID()
    }

    var accessToken: String? {
        session?.accessToken ?? storedSession?.accessToken
    }

    var userID: UUID? {
        session?.userID ?? storedSession?.userID
    }

    private func shouldRefreshSession(now: Date = Date()) -> Bool {
        guard let expiration = session?.expiresAt ?? storedSession?.accessTokenExpiresAt else {
            return false
        }

        return expiration.timeIntervalSince(now) <= tokenRefreshLeeway
    }

    private func scheduleRefresh(for session: SupabaseAuthSession) {
        refreshTask?.cancel()

        guard let expiresAt = session.expiresAt else {
            refreshTask = nil
            return
        }

        let refreshTime = expiresAt.addingTimeInterval(-tokenRefreshLeeway)
        let delay = max(refreshTime.timeIntervalSinceNow, 0)

        refreshTask = Task { @MainActor [weak self] in
            guard let self else { return }

            if delay > 0 {
                let nanoseconds = UInt64(delay * 1_000_000_000)
                try? await Task.sleep(nanoseconds: nanoseconds)
            }

            guard !Task.isCancelled else { return }

            do {
                try await self.refreshSession()
            } catch {
                #if DEBUG
                print("Failed to auto-refresh session: \(error)")
                #endif
            }
        }
    }

    private func mapSupabaseError(_ error: SupabaseError) -> AuthError {
        switch error {
        case .invalidResponse:
            return .invalidCredentials
        case let .requestFailed(statusCode, message):
            if (statusCode == 400 || statusCode == 409) && message.localizedCaseInsensitiveContains("already") {
                return .emailAlreadyRegistered
            }
            if statusCode == 400 || statusCode == 401 || statusCode == 403 || statusCode == 422 {
                return .invalidCredentials
            }
            return .invalidCredentials
        case .missingConfiguration:
            return .missingConfiguration
        }
    }
}
