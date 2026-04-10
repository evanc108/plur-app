import Foundation

struct Message: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var groupId: UUID
    var userId: UUID
    var senderName: String
    var content: String
    var isPinned: Bool
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, content
        case groupId = "group_id"
        case userId = "user_id"
        case senderName = "sender_name"
        case isPinned = "is_pinned"
        case createdAt = "created_at"
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "h:mm a"
        return f
    }()

    var timeText: String {
        Self.timeFormatter.string(from: createdAt)
    }
}
