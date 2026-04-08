import Foundation

struct Message: Codable, Identifiable {
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

    var timeText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: createdAt)
    }
}

struct Announcement: Codable, Identifiable {
    let id: UUID
    var groupId: UUID
    var userId: UUID
    var title: String
    var content: String
    var isPinned: Bool
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, title, content
        case groupId = "group_id"
        case userId = "user_id"
        case isPinned = "is_pinned"
        case createdAt = "created_at"
    }
}
