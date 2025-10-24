import Foundation

struct SupabaseConfiguration {
    let url: URL
    let apiKey: String

    init?(bundle: Bundle = .main, processInfo: ProcessInfo = .processInfo) {
        if let urlString = processInfo.environment["SUPABASE_URL"],
           let apiKey = processInfo.environment["SUPABASE_ANON_KEY"],
           let url = URL(string: urlString) {
            self.url = url
            self.apiKey = apiKey
            return
        }

        guard
            let urlString = bundle.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
            let url = URL(string: urlString),
            let apiKey = bundle.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String
        else {
            return nil
        }

        self.url = url
        self.apiKey = apiKey
    }
}

struct SupabaseAuthSession: Codable, Equatable {
    let accessToken: String
    let refreshToken: String?
    let userID: UUID
    let email: String
}

protocol SupabaseHouseholdMembershipService {
    func createMembership(householdID: UUID, userID: UUID, role: String, joinedAt: Date) async throws
    func signIn(email: String, password: String) async throws -> SupabaseAuthSession
    func signUp(email: String, password: String) async throws -> SupabaseAuthSession
}

enum SupabaseError: LocalizedError {
    case invalidResponse
    case requestFailed(statusCode: Int, message: String)
    case missingConfiguration

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Die Verbindung zu Supabase ist fehlgeschlagen."
        case let .requestFailed(statusCode, message):
            return "Supabase-Anfrage fehlgeschlagen (Status \(statusCode)): \(message)"
        case .missingConfiguration:
            return "Supabase-Konfiguration ist unvollständig."
        }
    }
}

final class SupabaseClient: SupabaseHouseholdMembershipService {
    private let configuration: SupabaseConfiguration?
    private let urlSession: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(configuration: SupabaseConfiguration? = SupabaseConfiguration(), urlSession: URLSession = .shared) {
        self.configuration = configuration
        self.urlSession = urlSession
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func createMembership(householdID: UUID, userID: UUID, role: String, joinedAt: Date = Date()) async throws {
        guard let configuration else {
            #if DEBUG
            print("Supabase configuration is missing – skipping household membership creation.")
            #endif
            return
        }

        var request = URLRequest(url: configuration.url.appendingPathComponent("rest/v1/household_memberships"))
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue(configuration.apiKey, forHTTPHeaderField: "apikey")
        request.addValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("return=minimal", forHTTPHeaderField: "Prefer")

        let payload = [HouseholdMembershipPayload(householdID: householdID, userID: userID, role: role, joinedAt: joinedAt)]
        request.httpBody = try encoder.encode(payload)

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unbekannte Fehlermeldung"
            throw SupabaseError.requestFailed(statusCode: httpResponse.statusCode, message: message)
        }
    }

    func signIn(email: String, password: String) async throws -> SupabaseAuthSession {
        let request = try authRequest(
            path: "auth/v1/token",
            queryItems: [URLQueryItem(name: "grant_type", value: "password")],
            body: AuthCredentials(email: email, password: password)
        )

        return try await performAuthRequest(request)
    }

    func signUp(email: String, password: String) async throws -> SupabaseAuthSession {
        let request = try authRequest(
            path: "auth/v1/signup",
            body: AuthCredentials(email: email, password: password)
        )

        return try await performAuthRequest(request)
    }
}

private extension SupabaseClient {
    struct AuthCredentials: Encodable {
        let email: String
        let password: String
    }

    struct AuthResponse: Decodable {
        let accessToken: String?
        let refreshToken: String?
        let tokenType: String?
        let expiresIn: Int?
        let user: SupabaseUser?
        let session: SessionPayload?

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case refreshToken = "refresh_token"
            case tokenType = "token_type"
            case expiresIn = "expires_in"
            case user
            case session
        }

        struct SessionPayload: Decodable {
            let accessToken: String?
            let refreshToken: String?
            let tokenType: String?
            let expiresIn: Int?
            let user: SupabaseUser?

            enum CodingKeys: String, CodingKey {
                case accessToken = "access_token"
                case refreshToken = "refresh_token"
                case tokenType = "token_type"
                case expiresIn = "expires_in"
                case user
            }
        }
    }

    struct SupabaseUser: Decodable {
        let id: UUID
        let email: String?
    }

    func authRequest(path: String, queryItems: [URLQueryItem] = [], body: AuthCredentials) throws -> URLRequest {
        guard let configuration else {
            throw SupabaseError.missingConfiguration
        }

        var url = configuration.url.appendingPathComponent(path)
        if var components = URLComponents(url: url, resolvingAgainstBaseURL: false), !queryItems.isEmpty {
            components.queryItems = queryItems
            if let composedURL = components.url {
                url = composedURL
            }
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = try encoder.encode(body)
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue(configuration.apiKey, forHTTPHeaderField: "apikey")
        request.addValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")
        return request
    }

    func performAuthRequest(_ request: URLRequest) async throws -> SupabaseAuthSession {
        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unbekannte Fehlermeldung"
            throw SupabaseError.requestFailed(statusCode: httpResponse.statusCode, message: message)
        }

        let authResponse = try decoder.decode(AuthResponse.self, from: data)
        if let session = authResponse.session {
            return try mapSessionPayload(session)
        }

        guard let accessToken = authResponse.accessToken,
              let user = authResponse.user else {
            throw SupabaseError.invalidResponse
        }

        return SupabaseAuthSession(
            accessToken: accessToken,
            refreshToken: authResponse.refreshToken,
            userID: user.id,
            email: user.email ?? ""
        )
    }

    func mapSessionPayload(_ payload: AuthResponse.SessionPayload) throws -> SupabaseAuthSession {
        guard let accessToken = payload.accessToken,
              let user = payload.user else {
            throw SupabaseError.invalidResponse
        }

        return SupabaseAuthSession(
            accessToken: accessToken,
            refreshToken: payload.refreshToken,
            userID: user.id,
            email: user.email ?? ""
        )
    }

    struct HouseholdMembershipPayload: Encodable {
        let householdID: UUID
        let userID: UUID
        let role: String
        let joinedAt: Date

        enum CodingKeys: String, CodingKey {
            case householdID = "household_id"
            case userID = "user_id"
            case role
            case joinedAt = "joined_at"
        }
    }
}
