//
//  KorbiApp.swift
//  Korbi
//
//  Created by Liam Schmid on 23.10.25.
//

import SwiftUI
import SwiftData

@main
struct KorbiApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    private let supabaseClient: SupabaseClient
    @StateObject private var settings: KorbiSettings
    @StateObject private var authManager: AuthManager
    @StateObject private var inviteCoordinator: InviteCoordinator

    init() {
        let client = SupabaseClient()
        self.supabaseClient = client
        let settings = KorbiSettings(supabaseClient: client)
        let authManager = AuthManager(supabaseClient: client)
        settings.configure(authManager: authManager)
        _settings = StateObject(wrappedValue: settings)
        _authManager = StateObject(wrappedValue: authManager)
        _inviteCoordinator = StateObject(wrappedValue: InviteCoordinator(settings: settings, authManager: authManager))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings)
                .environmentObject(authManager)
                .environmentObject(inviteCoordinator)
                .preferredColorScheme(settings.useWarmLightMode ? .light : nil)
                .onOpenURL { url in
                    inviteCoordinator.handleIncomingURL(url)
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
