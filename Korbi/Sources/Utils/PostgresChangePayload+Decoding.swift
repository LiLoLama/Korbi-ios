import Foundation
import Supabase

extension PostgresChangePayload {
  func decode<T: Decodable>() -> T? {
    guard let data = try? JSONSerialization.data(withJSONObject: new, options: []) else { return nil }
    return try? JSONDecoder().decode(T.self, from: data)
  }

  func decodeOld<T: Decodable>() -> T? {
    guard let data = try? JSONSerialization.data(withJSONObject: old, options: []) else { return nil }
    return try? JSONDecoder().decode(T.self, from: data)
  }
}
