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

protocol SupabaseHouseholdMembershipService {
    func createMembership(householdID: UUID, userID: UUID, role: String, joinedAt: Date) async throws
}

enum SupabaseError: LocalizedError {
    case invalidResponse
    case requestFailed(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Die Verbindung zu Supabase ist fehlgeschlagen."
        case let .requestFailed(statusCode, message):
            return "Supabase-Anfrage fehlgeschlagen (Status \(statusCode)): \(message)"
        }
    }
}

final class SupabaseClient: SupabaseHouseholdMembershipService {
    private let configuration: SupabaseConfiguration?
    private let urlSession: URLSession
    private let encoder: JSONEncoder

    init(configuration: SupabaseConfiguration? = SupabaseConfiguration(), urlSession: URLSession = .shared) {
        self.configuration = configuration
        self.urlSession = urlSession
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
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
}

private extension SupabaseClient {
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
