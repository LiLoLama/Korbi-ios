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

    init() {
        let client = SupabaseClient()
        self.supabaseClient = client
        _settings = StateObject(wrappedValue: KorbiSettings(supabaseClient: client))
        _authManager = StateObject(wrappedValue: AuthManager(supabaseClient: client))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings)
                .environmentObject(authManager)
                .preferredColorScheme(settings.useWarmLightMode ? .light : nil)
        }
        .modelContainer(sharedModelContainer)
    }
}
