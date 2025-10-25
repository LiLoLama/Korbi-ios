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

        init(session: SupabaseAuthSession, primaryHouseholdID: UUID = UUID(), fallbackEmail: String) {
            self.accessToken = session.accessToken
            self.refreshToken = session.refreshToken
            self.userID = session.userID
            self.email = session.email.isEmpty ? fallbackEmail : session.email
            self.primaryHouseholdID = primaryHouseholdID
        }
    }

    private let userDefaults: UserDefaults
    private let supabaseClient: SupabaseService
    private let storedSessionKey = "korbi.auth.session"

    private var storedSession: StoredSession? {
        didSet { persistSession() }
    }

    @Published private(set) var session: SupabaseAuthSession?

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
                email: storedSession.email
            )
        } else {
            storedSession = nil
            currentUserEmail = nil
            isAuthenticated = false
            session = nil
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
        isAuthenticated = false
        currentUserEmail = nil
        storedSession = nil
        userDefaults.removeObject(forKey: storedSessionKey)
        session = nil
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

        } catch {
            logout()
            throw error
        }
    }

    func performAuthenticatedRequest<T>(request: @escaping (String) async throws -> T) async throws -> T {
        // 1. Erster Versuch mit dem aktuellen Access Token
        if let token = accessToken {
            do {
                return try await request(token)
            } catch let error as SupabaseError {
                // Prüfen, ob der Fehler ein "Token abgelaufen" (401) ist
                if case let .requestFailed(statusCode, _) = error, statusCode == 401 {
                    // Token ist abgelaufen -> weiter zu Schritt 2
                } else {
                    // Anderer Fehler -> sofort weiterleiten
                    throw error
                }
            } catch {
                throw error
            }
        }

        // 2. Token erneuern
        try await refreshSession()

        // 3. Zweiter Versuch mit dem neuen Access Token
        guard let newToken = accessToken else {
            logout()
            throw AuthError.invalidCredentials
        }

        return try await request(newToken)
    }

    func loginAsDemoUser() {
        Task { @MainActor in
            try? await login(email: demoCredentials.email, password: demoCredentials.password)
        }
    }

    var demoCredentials: (email: String, password: String) {
        (normalize(demoEmail), demoPassword)
    }

    private let demoEmail = "test@korbi.com"
    private let demoPassword = "test"

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
