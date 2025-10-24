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
    @Published private(set) var currentUserID: UUID? = nil

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
    private let supabaseClient: SupabaseHouseholdMembershipService
    private let storedSessionKey = "korbi.auth.session"

    private var storedSession: StoredSession? {
        didSet { persistSession() }
    }

    init(
        userDefaults: UserDefaults = .standard,
        supabaseClient: SupabaseHouseholdMembershipService = SupabaseClient()
    ) {
        self.userDefaults = userDefaults
        self.supabaseClient = supabaseClient

        if let data = userDefaults.data(forKey: storedSessionKey),
           let storedSession = try? JSONDecoder().decode(StoredSession.self, from: data) {
            self.storedSession = storedSession
            currentUserEmail = storedSession.email
            currentUserID = storedSession.userID
            isAuthenticated = true
        } else {
            storedSession = nil
            currentUserEmail = nil
            currentUserID = nil
            isAuthenticated = false
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
            currentUserID = storedSession.userID
            isAuthenticated = true
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
            let session = try await supabaseClient.signUp(email: normalizedEmail, password: password)
            let primaryHouseholdID = UUID()
            let storedSession = StoredSession(
                session: session,
                primaryHouseholdID: primaryHouseholdID,
                fallbackEmail: normalizedEmail
            )
            self.storedSession = storedSession
            currentUserEmail = storedSession.email
            currentUserID = storedSession.userID
            isAuthenticated = true

            do {
                try await supabaseClient.createMembership(
                    householdID: primaryHouseholdID,
                    userID: session.userID,
                    role: "owner",
                    joinedAt: Date()
                )
            } catch {
                logout()
                throw error
            }
        } catch let error as SupabaseError {
            throw mapSupabaseError(error)
        }
    }

    func logout() {
        isAuthenticated = false
        currentUserEmail = nil
        currentUserID = nil
        storedSession = nil
        userDefaults.removeObject(forKey: storedSessionKey)
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

    func updateMembershipName(_ name: String, for householdID: UUID) async throws {
        guard let userID = currentUserID else { return }
        try await supabaseClient.updateMembershipName(householdID: householdID, userID: userID, name: name)
    }

    func fetchHouseholds() async throws -> [Household] {
        guard let userID = currentUserID else { return [] }
        let remoteHouseholds = try await supabaseClient.fetchHouseholds(for: userID)
        return remoteHouseholds.map { Household(id: $0.id, name: $0.name ?? "Haushalt") }
    }

    func fetchHouseholdMembers(for householdID: UUID) async throws -> [HouseholdMember] {
        let members = try await supabaseClient.fetchHouseholdMembers(householdID: householdID)
        return members.map { member in
            HouseholdMember(
                id: member.id ?? member.userID,
                name: member.name?.isEmpty == false ? member.name! : "Mitglied",
                role: member.role?.isEmpty == false ? member.role! : "Mitglied",
                status: member.status?.isEmpty == false ? member.status! : "Aktiv",
                imageName: "person.fill"
            )
        }
    }

    func membershipName(for householdID: UUID) async throws -> String? {
        guard let userID = currentUserID else { return nil }
        let membership = try await supabaseClient.fetchMembership(householdID: householdID, userID: userID)
        return membership?.name
    }

    func createHousehold(named name: String) async throws -> Household? {
        guard let userID = currentUserID else { return nil }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return nil }

        let identifier = UUID()
        try await supabaseClient.createHousehold(id: identifier, name: trimmedName)
        try await supabaseClient.createMembership(
            householdID: identifier,
            userID: userID,
            role: "owner",
            joinedAt: Date()
        )
        return Household(id: identifier, name: trimmedName)
    }

    func deleteHousehold(_ household: Household) async throws {
        try await supabaseClient.deleteHousehold(id: household.id)
    }

    func fetchItems() async throws -> [SupabaseItem] {
        try await supabaseClient.fetchItems()
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
