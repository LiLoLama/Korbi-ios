import Foundation
import SwiftUI

enum AuthError: LocalizedError, Equatable {
    case invalidEmail
    case passwordTooShort
    case passwordsDoNotMatch
    case emailAlreadyRegistered
    case invalidCredentials

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
        }
    }
}

@MainActor
final class AuthManager: ObservableObject {
    @Published private(set) var isAuthenticated: Bool = false
    @Published private(set) var currentUserEmail: String? = nil

    private struct StoredUser: Codable, Equatable {
        let id: UUID
        let email: String
        let password: String
        let primaryHouseholdID: UUID

        init(id: UUID = UUID(), email: String, password: String, primaryHouseholdID: UUID = UUID()) {
            self.id = id
            self.email = email
            self.password = password
            self.primaryHouseholdID = primaryHouseholdID
        }

        private enum CodingKeys: String, CodingKey {
            case id
            case email
            case password
            case primaryHouseholdID
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
            email = try container.decode(String.self, forKey: .email)
            password = try container.decode(String.self, forKey: .password)
            primaryHouseholdID = try container.decodeIfPresent(UUID.self, forKey: .primaryHouseholdID) ?? UUID()
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            try container.encode(email, forKey: .email)
            try container.encode(password, forKey: .password)
            try container.encode(primaryHouseholdID, forKey: .primaryHouseholdID)
        }
    }

    private let usersKey = "korbi.auth.users"
    private let loggedInEmailKey = "korbi.auth.loggedInEmail"

    private var users: [String: StoredUser] {
        didSet { persistUsers() }
    }

    init(
        userDefaults: UserDefaults = .standard,
        supabaseClient: SupabaseHouseholdMembershipService = SupabaseClient()
    ) {
        self.userDefaults = userDefaults
        self.supabaseClient = supabaseClient
        if let data = userDefaults.data(forKey: usersKey),
           let storedUsers = try? JSONDecoder().decode([String: StoredUser].self, from: data) {
            users = storedUsers
        } else {
            users = [:]
        }

        let demoUserUpdated = ensureDemoUserExists()
        if demoUserUpdated {
            persistUsers()
        }

        if let loggedInEmail = userDefaults.string(forKey: loggedInEmailKey),
           users[loggedInEmail] != nil {
            currentUserEmail = loggedInEmail
            isAuthenticated = true
        } else {
            currentUserEmail = nil
            isAuthenticated = false
        }
    }

    private let userDefaults: UserDefaults
    private let supabaseClient: SupabaseHouseholdMembershipService

    func login(email: String, password: String) async throws {
        let normalizedEmail = normalize(email)
        guard
            let user = users[normalizedEmail],
            user.password == password
        else {
            throw AuthError.invalidCredentials
        }

        currentUserEmail = normalizedEmail
        isAuthenticated = true
        persistLoggedInEmail(normalizedEmail)
    }

    func register(email: String, password: String, confirmation: String) async throws {
        let normalizedEmail = normalize(email)

        guard isValidEmail(normalizedEmail) else { throw AuthError.invalidEmail }
        guard password.count >= 6 else { throw AuthError.passwordTooShort }
        guard password == confirmation else { throw AuthError.passwordsDoNotMatch }
        guard users[normalizedEmail] == nil else { throw AuthError.emailAlreadyRegistered }

        let user = StoredUser(email: normalizedEmail, password: password)
        users[normalizedEmail] = user
        currentUserEmail = normalizedEmail
        isAuthenticated = true
        persistLoggedInEmail(normalizedEmail)

        do {
            try await supabaseClient.createMembership(
                householdID: user.primaryHouseholdID,
                userID: user.id,
                role: "owner",
                joinedAt: Date()
            )
        } catch {
            users.removeValue(forKey: normalizedEmail)
            logout()
            throw error
        }
    }

    func logout() {
        isAuthenticated = false
        currentUserEmail = nil
        userDefaults.removeObject(forKey: loggedInEmailKey)
    }

    func loginAsDemoUser() {
        let normalizedEmail = normalize(demoEmail)
        if let demoUser = users[normalizedEmail] {
            currentUserEmail = demoUser.email
            isAuthenticated = true
            persistLoggedInEmail(demoUser.email)
        }
    }

    var demoCredentials: (email: String, password: String) {
        (normalize(demoEmail), demoPassword)
    }

    private let demoEmail = "test@korbi.com"
    private let demoPassword = "test"

    @discardableResult
    private func ensureDemoUserExists() -> Bool {
        let normalizedEmail = normalize(demoEmail)
        let demoUser = StoredUser(email: normalizedEmail, password: demoPassword)
        guard users[normalizedEmail] != demoUser else { return false }

        users[normalizedEmail] = demoUser
        return true
    }

    private func persistUsers() {
        if let data = try? JSONEncoder().encode(users) {
            userDefaults.set(data, forKey: usersKey)
        }
    }

    private func persistLoggedInEmail(_ email: String) {
        userDefaults.set(email, forKey: loggedInEmailKey)
    }

    private func normalize(_ email: String) -> String {
        return email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func isValidEmail(_ email: String) -> Bool {
        let pattern = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
        let predicate = NSPredicate(format: "SELF MATCHES %@", pattern)
        return predicate.evaluate(with: email)
    }
}
