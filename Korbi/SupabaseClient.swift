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
    func createHousehold(id: UUID, name: String, ownerID: UUID) async throws
    func deleteHousehold(id: UUID) async throws
    func fetchHouseholdMembers(householdID: UUID) async throws -> [SupabaseHouseholdMember]
    func fetchHouseholds(for userID: UUID) async throws -> [SupabaseHousehold]
    func fetchPrimaryHouseholdID(for userID: UUID) async throws -> UUID?
    func fetchItems() async throws -> [SupabaseItem]
    func fetchMembership(householdID: UUID, userID: UUID) async throws -> SupabaseHouseholdMember?
    func signIn(email: String, password: String) async throws -> SupabaseAuthSession
    func signUp(email: String, password: String) async throws -> SupabaseAuthSession
    func updateMembershipName(householdID: UUID, userID: UUID, name: String) async throws
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
        guard configuration != nil else {
            #if DEBUG
            print("Supabase configuration is missing – skipping household membership creation.")
            #endif
            return
        }

        var request = try restRequest(
            path: "rest/v1/household_memberships",
            method: "POST",
            prefer: "return=minimal"
        )

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

    func createHousehold(id: UUID, name: String, ownerID: UUID) async throws {
        guard configuration != nil else {
            #if DEBUG
            print("Supabase configuration is missing – skipping household creation.")
            #endif
            return
        }

        var request = try restRequest(
            path: "rest/v1/households",
            method: "POST",
            prefer: "return=minimal"
        )

        let payload = [HouseholdPayload(id: id, name: name, ownerID: ownerID)]
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

    func deleteHousehold(id: UUID) async throws {
        guard configuration != nil else {
            #if DEBUG
            print("Supabase configuration is missing – skipping household deletion.")
            #endif
            return
        }

        let request = try restRequest(
            path: "rest/v1/households",
            method: "DELETE",
            queryItems: [URLQueryItem(name: "id", value: "eq.\(id.uuidString)")],
            prefer: "return=minimal"
        )

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unbekannte Fehlermeldung"
            throw SupabaseError.requestFailed(statusCode: httpResponse.statusCode, message: message)
        }
    }

    func fetchHouseholdMembers(householdID: UUID) async throws -> [SupabaseHouseholdMember] {
        guard configuration != nil else {
            #if DEBUG
            print("Supabase configuration is missing – returning empty household members.")
            #endif
            return []
        }

        let request = try restRequest(
            path: "rest/v1/household_memberships",
            queryItems: [
                URLQueryItem(name: "select", value: "id,user_id,name,role,status"),
                URLQueryItem(name: "household_id", value: "eq.\(householdID.uuidString)")
            ]
        )

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unbekannte Fehlermeldung"
            throw SupabaseError.requestFailed(statusCode: httpResponse.statusCode, message: message)
        }

        return try decoder.decode([SupabaseHouseholdMember].self, from: data)
    }

    func fetchHouseholds(for userID: UUID) async throws -> [SupabaseHousehold] {
        guard configuration != nil else {
            #if DEBUG
            print("Supabase configuration is missing – returning empty households.")
            #endif
            return []
        }

        let request = try restRequest(
            path: "rest/v1/household_memberships",
            queryItems: [
                URLQueryItem(name: "select", value: "households(id,name)"),
                URLQueryItem(name: "user_id", value: "eq.\(userID.uuidString)")
            ]
        )

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unbekannte Fehlermeldung"
            throw SupabaseError.requestFailed(statusCode: httpResponse.statusCode, message: message)
        }

        let memberships = try decoder.decode([HouseholdMembershipWithHousehold].self, from: data)
        return memberships.compactMap { record in
            if let household = record.household {
                return SupabaseHousehold(id: household.id, name: household.name)
            }
            if let id = record.householdID {
                return SupabaseHousehold(id: id, name: nil)
            }
            return nil
        }
    }

    func fetchPrimaryHouseholdID(for userID: UUID) async throws -> UUID? {
        guard configuration != nil else {
            #if DEBUG
            print("Supabase configuration is missing – returning nil primary household ID.")
            #endif
            return nil
        }

        let request = try restRequest(
            path: "rest/v1/household_memberships",
            queryItems: [
                URLQueryItem(name: "select", value: "household_id"),
                URLQueryItem(name: "user_id", value: "eq.\(userID.uuidString)"),
                URLQueryItem(name: "order", value: "joined_at.asc"),
                URLQueryItem(name: "limit", value: "1")
            ]
        )

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unbekannte Fehlermeldung"
            throw SupabaseError.requestFailed(statusCode: httpResponse.statusCode, message: message)
        }

        let memberships = try decoder.decode([HouseholdIdentifierRecord].self, from: data)
        return memberships.first?.householdID
    }

    func fetchItems() async throws -> [SupabaseItem] {
        guard configuration != nil else {
            #if DEBUG
            print("Supabase configuration is missing – returning empty items.")
            #endif
            return []
        }

        let request = try restRequest(
            path: "rest/v1/items",
            queryItems: [URLQueryItem(name: "select", value: "id,name,description,quantity,category")]
        )

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unbekannte Fehlermeldung"
            throw SupabaseError.requestFailed(statusCode: httpResponse.statusCode, message: message)
        }

        return try decoder.decode([SupabaseItem].self, from: data)
    }

    func fetchMembership(householdID: UUID, userID: UUID) async throws -> SupabaseHouseholdMember? {
        guard configuration != nil else {
            #if DEBUG
            print("Supabase configuration is missing – returning nil membership.")
            #endif
            return nil
        }

        let request = try restRequest(
            path: "rest/v1/household_memberships",
            queryItems: [
                URLQueryItem(name: "select", value: "id,user_id,name,role,status"),
                URLQueryItem(name: "household_id", value: "eq.\(householdID.uuidString)"),
                URLQueryItem(name: "user_id", value: "eq.\(userID.uuidString)")
            ]
        )

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unbekannte Fehlermeldung"
            throw SupabaseError.requestFailed(statusCode: httpResponse.statusCode, message: message)
        }

        let memberships = try decoder.decode([SupabaseHouseholdMember].self, from: data)
        return memberships.first
    }

    func updateMembershipName(householdID: UUID, userID: UUID, name: String) async throws {
        guard configuration != nil else {
            #if DEBUG
            print("Supabase configuration is missing – skipping membership name update.")
            #endif
            return
        }

        var request = try restRequest(
            path: "rest/v1/household_memberships",
            method: "PATCH",
            queryItems: [
                URLQueryItem(name: "household_id", value: "eq.\(householdID.uuidString)"),
                URLQueryItem(name: "user_id", value: "eq.\(userID.uuidString)")
            ],
            prefer: "return=minimal"
        )

        request.httpBody = try encoder.encode(HouseholdMembershipUpdatePayload(name: name))

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

    func restRequest(
        path: String,
        method: String = "GET",
        queryItems: [URLQueryItem] = [],
        prefer: String? = nil
    ) throws -> URLRequest {
        guard let configuration else {
            throw SupabaseError.missingConfiguration
        }

        var components = URLComponents(url: configuration.url.appendingPathComponent(path), resolvingAgainstBaseURL: false)
        components?.queryItems = queryItems.isEmpty ? nil : queryItems

        guard let url = components?.url else {
            throw SupabaseError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue(configuration.apiKey, forHTTPHeaderField: "apikey")
        request.addValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")
        if let prefer {
            request.addValue(prefer, forHTTPHeaderField: "Prefer")
        }
        if method != "GET" {
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        return request
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

    struct HouseholdPayload: Encodable {
        let id: UUID
        let name: String
        let ownerID: UUID

        enum CodingKeys: String, CodingKey {
            case id
            case name
            case ownerID = "owner_id"
        }
    }

    struct HouseholdMembershipUpdatePayload: Encodable {
        let name: String
    }
}

struct SupabaseHousehold: Decodable {
    let id: UUID
    let name: String?
}

struct SupabaseHouseholdMember: Decodable {
    let id: UUID?
    let userID: UUID
    let name: String?
    let role: String?
    let status: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case name
        case role
        case status
    }
}

struct SupabaseItem: Decodable, Identifiable {
    let id: UUID?
    let name: String
    let description: String?
    let quantity: String?
    let category: String?
}

private struct HouseholdMembershipWithHousehold: Decodable {
    let household: SupabaseHousehold?
    let householdID: UUID?

    enum CodingKeys: String, CodingKey {
        case household = "households"
        case householdID = "household_id"
    }
}

private struct HouseholdIdentifierRecord: Decodable {
    let householdID: UUID

    enum CodingKeys: String, CodingKey {
        case householdID = "household_id"
    }
}
