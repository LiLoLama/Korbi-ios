import Foundation
import Supabase

extension AnyAction {
  func decodeRecord<T: Decodable>(
    as type: T.Type = T.self,
    decoder: JSONDecoder = AnyJSON.decoder
  ) -> T? {
    switch self {
    case let .insert(action):
      return try? action.decodeRecord(as: type, decoder: decoder)
    case let .update(action):
      return try? action.decodeRecord(as: type, decoder: decoder)
    case .delete:
      return nil
    }
  }

  func decodeOldRecord<T: Decodable>(
    as type: T.Type = T.self,
    decoder: JSONDecoder = AnyJSON.decoder
  ) -> T? {
    switch self {
    case let .update(action):
      return try? action.decodeOldRecord(as: type, decoder: decoder)
    case let .delete(action):
      return try? action.decodeOldRecord(as: type, decoder: decoder)
    case .insert:
      return nil
    }
  }
}
