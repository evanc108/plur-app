import Foundation

struct Message: Codable, Identifiable {
    let id: UUID
    var groupId: UUID
    var userId: UUID
    var content: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case groupId = "group_id"
        case userId = "user_id"
        case content
        case createdAt = "created_at"
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
        case id
        case groupId = "group_id"
        case userId = "user_id"
        case title
        case content
        case isPinned = "is_pinned"
        case createdAt = "created_at"
    }
}
