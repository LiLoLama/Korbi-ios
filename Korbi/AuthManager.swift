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
    @Published private(set) var isAuthenticated: Bool
    @Published private(set) var currentUserEmail: String?

    private struct StoredUser: Codable {
        let email: String
        let password: String
    }

    private let usersKey = "korbi.auth.users"
    private let loggedInEmailKey = "korbi.auth.loggedInEmail"

    private var users: [String: StoredUser] {
        didSet { persistUsers() }
    }

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        if let data = userDefaults.data(forKey: usersKey),
           let storedUsers = try? JSONDecoder().decode([String: StoredUser].self, from: data) {
            users = storedUsers
        } else {
            users = [:]
        }

        ensureDemoUserExists()

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

    func login(email: String, password: String) throws {
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

    func register(email: String, password: String, confirmation: String) throws {
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
    }

    func logout() {
        isAuthenticated = false
        currentUserEmail = nil
        userDefaults.removeObject(forKey: loggedInEmailKey)
    }

    func loginAsDemoUser() {
        if let demoUser = users[demoEmail] {
            currentUserEmail = demoUser.email
            isAuthenticated = true
            persistLoggedInEmail(demoUser.email)
        }
    }

    var demoCredentials: (email: String, password: String) {
        (demoEmail, demoPassword)
    }

    private let demoEmail = "test@korbi.com"
    private let demoPassword = "test"

    private func ensureDemoUserExists() {
        if users[demoEmail] == nil {
            users[demoEmail] = StoredUser(email: demoEmail, password: demoPassword)
        }
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
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func isValidEmail(_ email: String) -> Bool {
        let pattern = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}".
            trimmingCharacters(in: .whitespaces)
        let predicate = NSPredicate(format: "SELF MATCHES %@", pattern)
        return predicate.evaluate(with: email)
    }
}
