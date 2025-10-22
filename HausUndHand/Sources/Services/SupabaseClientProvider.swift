import Foundation
import Supabase

final class SupabaseClientProvider {
  let client: SupabaseClient

  init(configuration: AppConfiguration) {
    let supabaseURL = configuration.supabaseURL
    client = SupabaseClient(supabaseURL: supabaseURL, supabaseKey: configuration.supabaseAnonKey)
  }
}
