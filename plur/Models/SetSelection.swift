import Foundation

struct SetSelection: Codable, Identifiable {
    let id: UUID
    var userId: UUID
    var groupId: UUID
    var artistId: Int
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case groupId = "group_id"
        case artistId = "artist_id"
        case createdAt = "created_at"
    }
}
