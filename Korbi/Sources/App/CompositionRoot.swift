import Foundation
import Combine
import Supabase

final class CompositionRoot: ObservableObject {
  let config: AppConfiguration
  let supabaseProvider: SupabaseClientProvider
  let authService: AuthServicing
  let householdService: HouseholdServicing
  let listsService: ListsServicing
  let itemsService: ItemsServicing
  let realtimeService: RealtimeServicing
  let voiceService: VoiceServicing

  let appState = AppState()

  private var cancellables: Set<AnyCancellable> = []

  init() {
    do {
      config = try AppConfiguration.load()
    } catch {
      fatalError("Config.plist konnte nicht geladen werden: \(error)")
    }

    supabaseProvider = SupabaseClientProvider(configuration: config)
    authService = AuthService(client: supabaseProvider.client)
    householdService = HouseholdService(client: supabaseProvider.client, appState: appState)
    listsService = ListsService(client: supabaseProvider.client, appState: appState)
    itemsService = ItemsService(client: supabaseProvider.client, realtimeService: nil, appState: appState)
    realtimeService = RealtimeService(client: supabaseProvider.client, appState: appState)
    voiceService = VoiceService(configuration: config, signer: HMACSigner.shared, urlSession: .shared)

    if let realtime = realtimeService as? RealtimeService {
      itemsService.realtimeService = realtime
    }

    bindAuth()

    voiceService.statePublisher
      .receive(on: DispatchQueue.main)
      .sink { [weak self] state in
        self?.appState.voiceState = state
      }
      .store(in: &cancellables)
  }

  private func bindAuth() {
    authService.authStatePublisher
      .receive(on: DispatchQueue.main)
      .sink { [weak self] session in
        self?.appState.session = session
      }
      .store(in: &cancellables)
  }
}

final class AppState: ObservableObject {
  @Published var session: AuthSession?
  @Published var households: [HouseholdEntity] = []
  @Published var activeHouseholdID: UUID?
  @Published var lists: [ListEntity] = []
  @Published var items: [UUID: [ItemEntity]] = [:]
  @Published var voiceState = VoiceSessionState()

  func items(for listID: UUID) -> [ItemEntity] {
    items[listID] ?? []
  }
}

struct AppConfiguration: Codable {
  let supabaseURL: URL
  let supabaseAnonKey: String
  let n8nWebhookURL: URL
  let hmacSharedSecret: String

  enum CodingKeys: String, CodingKey {
    case supabaseURL = "SUPABASE_URL"
    case supabaseAnonKey = "SUPABASE_ANON_KEY"
    case n8nWebhookURL = "N8N_WEBHOOK_URL"
    case hmacSharedSecret = "HMAC_SHARED_SECRET"
  }

  static func load(bundle: Bundle = .main) throws -> AppConfiguration {
    guard let url = bundle.url(forResource: "Config", withExtension: "plist") else {
      throw ConfigurationError.missingFile
    }
    let data = try Data(contentsOf: url)
    let decoder = PropertyListDecoder()
    return try decoder.decode(AppConfiguration.self, from: data)
  }

  enum ConfigurationError: Error {
    case missingFile
  }
}

struct AuthSession: Equatable {
  let userID: UUID
  let email: String?
}
