import Foundation

enum InviteRole: String, Codable, CaseIterable, Identifiable {
    case viewer
    case editor

    var id: String { rawValue }
}
