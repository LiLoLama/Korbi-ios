import Foundation

struct SupabaseConfiguration {
    let url: URL
    let apiKey: String

    init?(bundle: Bundle = .main) {
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
    let expiresAt: Date?
}

protocol SupabaseService {
    func createMembership(householdID: UUID, userID: UUID, role: String, joinedAt: Date) async throws
    func updateMembershipEmail(userID: UUID, email: String) async throws
    func signIn(email: String, password: String) async throws -> SupabaseAuthSession
    func signUp(email: String, password: String) async throws -> SupabaseAuthSession
    func refreshToken(refreshToken: String) async throws -> SupabaseAuthSession
    func fetchHouseholds(accessToken: String) async throws -> [SupabaseHousehold]
    func createHousehold(id: UUID, name: String, accessToken: String) async throws
    func deleteHousehold(id: UUID, accessToken: String) async throws
    func updateHouseholdName(id: UUID, name: String, accessToken: String) async throws
    func fetchHouseholdMembers(householdID: UUID, accessToken: String) async throws -> [SupabaseHouseholdMember]
    func fetchMemberships(userID: UUID, accessToken: String) async throws -> [SupabaseMembership]
    func updateHouseholdMemberName(userID: UUID, householdID: UUID, name: String, accessToken: String) async throws
    func fetchItems(accessToken: String, householdID: UUID?) async throws -> [SupabaseItem]
    func deleteItem(id: UUID, accessToken: String) async throws
    func sendHouseholdNotification(message: String, householdID: UUID, accessToken: String) async throws
    func createInvite(
        householdID: UUID,
        email: String?,
        role: InviteRole,
        ttlHours: Int,
        accessToken: String
    ) async throws -> SupabaseInvite
    func revokeInvite(inviteID: UUID, accessToken: String) async throws
    func acceptInvite(token: String, accessToken: String) async throws -> SupabaseInviteAcceptance
    func leaveHousehold(householdID: UUID, userID: UUID, accessToken: String) async throws
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

final class SupabaseClient: SupabaseService {
    private let configuration: SupabaseConfiguration?
    private let urlSession: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(configuration: SupabaseConfiguration? = SupabaseConfiguration(), urlSession: URLSession = .shared) {
        self.configuration = configuration
        self.urlSession = urlSession
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = SupabaseClient.dateEncodingStrategy
        self.encoder = encoder
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = SupabaseClient.dateDecodingStrategy
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

    func updateMembershipEmail(userID: UUID, email: String) async throws {
        guard let configuration else {
            #if DEBUG
            print("Supabase configuration is missing – skipping household membership email update.")
            #endif
            return
        }

        guard var components = URLComponents(url: configuration.url.appendingPathComponent("rest/v1/household_memberships"), resolvingAgainstBaseURL: false) else {
            throw SupabaseError.invalidResponse
        }
        components.queryItems = [URLQueryItem(name: "user_id", value: "eq.\(userID.uuidString)")]

        guard let url = components.url else {
            throw SupabaseError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue(configuration.apiKey, forHTTPHeaderField: "apikey")
        request.addValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("return=minimal", forHTTPHeaderField: "Prefer")

        let payload = ["email": email]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])

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

    func refreshToken(refreshToken: String) async throws -> SupabaseAuthSession {
        let request = try authRequest(
            path: "auth/v1/token",
            queryItems: [URLQueryItem(name: "grant_type", value: "refresh_token")],
            body: RefreshTokenPayload(refreshToken: refreshToken)
        )

        return try await performAuthRequest(request)
    }

    func fetchHouseholds(accessToken: String) async throws -> [SupabaseHousehold] {
        let request = try dataRequest(
            path: "rest/v1/households",
            method: "GET",
            queryItems: [URLQueryItem(name: "select", value: "*")],
            accessToken: accessToken
        )
        return try await performDecodingRequest(request)
    }

    func createHousehold(id: UUID, name: String, accessToken: String) async throws {
        let payload = [SupabaseHousehold(id: id, name: name)]
        var request = try dataRequest(
            path: "rest/v1/households",
            method: "POST",
            accessToken: accessToken
        )
        request.addValue("return=minimal", forHTTPHeaderField: "Prefer")
        request.httpBody = try encoder.encode(payload)
        try await performEmptyRequest(request)
    }

    func deleteHousehold(id: UUID, accessToken: String) async throws {
        let request = try dataRequest(
            path: "rest/v1/households",
            method: "DELETE",
            queryItems: [URLQueryItem(name: "id", value: "eq.\(id.uuidString)")],
            accessToken: accessToken
        )
        try await performEmptyRequest(request)
    }

    func updateHouseholdName(id: UUID, name: String, accessToken: String) async throws {
        var request = try dataRequest(
            path: "rest/v1/households",
            method: "PATCH",
            queryItems: [URLQueryItem(name: "id", value: "eq.\(id.uuidString)")],
            accessToken: accessToken
        )
        request.addValue("return=representation", forHTTPHeaderField: "Prefer")
        let payload = ["name": name]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])
        _ = try await performDecodingRequest(request) as [SupabaseHousehold]
    }

    func fetchHouseholdMembers(householdID: UUID, accessToken: String) async throws -> [SupabaseHouseholdMember] {
        let request = try dataRequest(
            path: "rest/v1/household_memberships",
            method: "GET",
            queryItems: [
                URLQueryItem(name: "household_id", value: "eq.\(householdID.uuidString)"),
                URLQueryItem(name: "select", value: "*")
            ],
            accessToken: accessToken
        )
        return try await performDecodingRequest(request)
    }

    func fetchMemberships(userID: UUID, accessToken: String) async throws -> [SupabaseMembership] {
        let request = try dataRequest(
            path: "rest/v1/household_memberships",
            method: "GET",
            queryItems: [
                URLQueryItem(name: "user_id", value: "eq.\(userID.uuidString)"),
                URLQueryItem(name: "select", value: "household_id,role")
            ],
            accessToken: accessToken
        )
        return try await performDecodingRequest(request)
    }

    func updateHouseholdMemberName(userID: UUID, householdID: UUID, name: String, accessToken: String) async throws {
        var request = try dataRequest(
            path: "rest/v1/household_memberships",
            method: "PATCH",
            queryItems: [
                URLQueryItem(name: "household_id", value: "eq.\(householdID.uuidString)"),
                URLQueryItem(name: "user_id", value: "eq.\(userID.uuidString)")
            ],
            accessToken: accessToken
        )
        request.addValue("return=representation", forHTTPHeaderField: "Prefer")
        let payload = ["name": name]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])
        _ = try await performDecodingRequest(request) as [SupabaseHouseholdMember]
    }

    func fetchItems(accessToken: String, householdID: UUID?) async throws -> [SupabaseItem] {
        var queryItems: [URLQueryItem] = []
        queryItems.append(URLQueryItem(name: "select", value: "*"))
        if let householdID {
            queryItems.append(URLQueryItem(name: "household_id", value: "eq.\(householdID.uuidString)"))
        }
        let request = try dataRequest(
            path: "rest/v1/items",
            method: "GET",
            queryItems: queryItems,
            accessToken: accessToken
        )
        return try await performDecodingRequest(request)
    }

    func deleteItem(id: UUID, accessToken: String) async throws {
        let request = try dataRequest(
            path: "rest/v1/items",
            method: "DELETE",
            queryItems: [URLQueryItem(name: "id", value: "eq.\(id.uuidString)")],
            accessToken: accessToken
        )
        try await performEmptyRequest(request)
    }

    func sendHouseholdNotification(message: String, householdID: UUID, accessToken: String) async throws {
        var request = try dataRequest(
            path: "rest/v1/notifications",
            method: "POST",
            accessToken: accessToken
        )
        request.addValue("return=minimal", forHTTPHeaderField: "Prefer")
        let payload = [HouseholdNotificationPayload(householdID: householdID, message: message)]
        request.httpBody = try encoder.encode(payload)
        try await performEmptyRequest(request)
    }

    func createInvite(
        householdID: UUID,
        email: String?,
        role: InviteRole,
        ttlHours: Int,
        accessToken: String
    ) async throws -> SupabaseInvite {
        var request = try dataRequest(
            path: "rest/v1/rpc/create_invite",
            method: "POST",
            accessToken: accessToken
        )
        request.httpBody = try encoder.encode(
            InviteCreationPayload(
                householdID: householdID,
                email: email,
                role: role,
                ttlHours: ttlHours
            )
        )
        return try await performDecodingRequest(request)
    }

    func revokeInvite(inviteID: UUID, accessToken: String) async throws {
        var request = try dataRequest(
            path: "rest/v1/rpc/revoke_invite",
            method: "POST",
            accessToken: accessToken
        )
        request.httpBody = try encoder.encode(InviteRevocationPayload(inviteID: inviteID))
        try await performEmptyRequest(request)
    }

    func acceptInvite(token: String, accessToken: String) async throws -> SupabaseInviteAcceptance {
        var request = try dataRequest(
            path: "rest/v1/rpc/accept_invite",
            method: "POST",
            accessToken: accessToken
        )
        request.httpBody = try encoder.encode(InviteAcceptancePayload(token: token))
        return try await performDecodingRequest(request)
    }

    func leaveHousehold(householdID: UUID, userID: UUID, accessToken: String) async throws {
        let request = try dataRequest(
            path: "rest/v1/household_memberships",
            method: "DELETE",
            queryItems: [
                URLQueryItem(name: "household_id", value: "eq.\(householdID.uuidString)"),
                URLQueryItem(name: "user_id", value: "eq.\(userID.uuidString)")
            ],
            accessToken: accessToken
        )
        try await performEmptyRequest(request)
    }
}

private extension SupabaseClient {
    static let fractionalSecondsFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    static let internetDateTimeFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    static var dateDecodingStrategy: JSONDecoder.DateDecodingStrategy {
        .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)

            if let date = fractionalSecondsFormatter.date(from: string) {
                return date
            }

            if let date = internetDateTimeFormatter.date(from: string) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Date string does not match expected ISO8601 formats"
            )
        }
    }

    static var dateEncodingStrategy: JSONEncoder.DateEncodingStrategy {
        .custom { date, encoder in
            var container = encoder.singleValueContainer()
            let string = fractionalSecondsFormatter.string(from: date)
            try container.encode(string)
        }
    }
}

private extension SupabaseClient {
    struct AuthCredentials: Encodable {
        let email: String
        let password: String
    }

    struct RefreshTokenPayload: Encodable {
        let refreshToken: String

        enum CodingKeys: String, CodingKey {
            case refreshToken = "refresh_token"
        }
    }

    struct InviteCreationPayload: Encodable {
        let householdID: UUID
        let email: String?
        let role: InviteRole
        let ttlHours: Int

        enum CodingKeys: String, CodingKey {
            case householdID = "p_household_id"
            case email = "p_email"
            case role = "p_role"
            case ttlHours = "p_ttl_hours"
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(householdID, forKey: .householdID)
            if let email {
                try container.encode(email, forKey: .email)
            } else {
                try container.encodeNil(forKey: .email)
            }
            try container.encode(role, forKey: .role)
            try container.encode(ttlHours, forKey: .ttlHours)
        }
    }

    struct InviteRevocationPayload: Encodable {
        let inviteID: UUID

        enum CodingKeys: String, CodingKey {
            case inviteID = "p_invite_id"
        }
    }

    struct InviteAcceptancePayload: Encodable {
        let token: String

        enum CodingKeys: String, CodingKey {
            case token = "p_token"
        }
    }

    struct HouseholdNotificationPayload: Encodable {
        let householdID: UUID
        let message: String

        enum CodingKeys: String, CodingKey {
            case householdID = "household_id"
            case message
        }
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

    func authRequest(path: String, queryItems: [URLQueryItem] = [], body: Encodable) throws -> URLRequest {
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

    func dataRequest(path: String, method: String, queryItems: [URLQueryItem] = [], accessToken: String) throws -> URLRequest {
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
        request.httpMethod = method
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(configuration.apiKey, forHTTPHeaderField: "apikey")
        let bearerToken = accessToken.isEmpty ? configuration.apiKey : accessToken
        request.addValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
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

        if let accessToken = authResponse.accessToken, let user = authResponse.user {
            return SupabaseAuthSession(
                accessToken: accessToken,
                refreshToken: authResponse.refreshToken,
                userID: user.id,
                email: user.email ?? "",
                expiresAt: expirationDate(from: authResponse.expiresIn)
            )
        }

        if let user = authResponse.user {
            return SupabaseAuthSession(
                accessToken: authResponse.accessToken ?? "",
                refreshToken: authResponse.refreshToken,
                userID: user.id,
                email: user.email ?? "",
                expiresAt: expirationDate(from: authResponse.expiresIn)
            )
        }

        // Supabase can return a 200 status with neither a session nor a populated user
        // when email confirmation is required. Surface an empty session so the caller
        // can treat it as a pending confirmation instead of an error.
        if (authResponse.accessToken?.isEmpty ?? true),
           authResponse.refreshToken == nil,
           authResponse.session == nil {
            return SupabaseAuthSession(
                accessToken: "",
                refreshToken: nil,
                userID: UUID(),
                email: "",
                expiresAt: expirationDate(from: authResponse.expiresIn)
            )
        }

        throw SupabaseError.invalidResponse
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
            email: user.email ?? "",
            expiresAt: expirationDate(from: payload.expiresIn)
        )
    }

    func expirationDate(from expiresIn: Int?) -> Date? {
        guard let expiresIn else { return nil }
        return Date().addingTimeInterval(TimeInterval(expiresIn))
    }

    func performDecodingRequest<Response: Decodable>(_ request: URLRequest) async throws -> Response {
        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unbekannte Fehlermeldung"
            throw SupabaseError.requestFailed(statusCode: httpResponse.statusCode, message: message)
        }

        return try decoder.decode(Response.self, from: data)
    }

    func performEmptyRequest(_ request: URLRequest) async throws {
        let (_, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let statusCode = httpResponse.statusCode
            throw SupabaseError.requestFailed(statusCode: statusCode, message: "Request failed")
        }
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

struct SupabaseHousehold: Codable, Identifiable, Equatable {
    let id: UUID
    let name: String
}

struct SupabaseHouseholdMember: Codable, Identifiable, Equatable {
    let householdID: UUID
    let userID: UUID
    let role: String?
    let status: String?
    let name: String?
    let email: String?

    enum CodingKeys: String, CodingKey {
        case householdID = "household_id"
        case userID = "user_id"
        case role
        case status
        case name
        case email
    }

    var id: String {
        "\(householdID.uuidString)-\(userID.uuidString)"
    }
}

struct SupabaseMembership: Codable, Equatable {
    let householdID: UUID
    let role: String?

    enum CodingKeys: String, CodingKey {
        case householdID = "household_id"
        case role
    }
}

struct SupabaseItem: Codable, Identifiable, Equatable {
    let id: UUID
    let householdID: UUID?
    let name: String
    let description: String?
    let quantity: String?
    let category: String?

    enum CodingKeys: String, CodingKey {
        case id
        case householdID = "household_id"
        case name
        case description
        case quantity
        case category
    }
}

struct SupabaseInvite: Codable, Identifiable, Equatable {
    let id: UUID
    let token: String
    let expiresAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case token
        case expiresAt = "expires_at"
    }
}

struct SupabaseInviteAcceptance: Codable, Equatable {
    let householdID: UUID
    let householdName: String?

    enum CodingKeys: String, CodingKey {
        case householdID = "household_id"
        case householdName = "household_name"
    }
}
