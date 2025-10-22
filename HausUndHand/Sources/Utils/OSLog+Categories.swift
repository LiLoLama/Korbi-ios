import Foundation
import OSLog

extension OSLog {
  private static var subsystem = Bundle.main.bundleIdentifier ?? "HausUndHand"

  static let auth = Logger(subsystem: subsystem, category: "Auth")
  static let lists = Logger(subsystem: subsystem, category: "Lists")
  static let items = Logger(subsystem: subsystem, category: "Items")
  static let voice = Logger(subsystem: subsystem, category: "Voice")
}
