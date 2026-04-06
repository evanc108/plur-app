import Foundation

struct Photo: Codable, Identifiable {
    let id: UUID
    var groupId: UUID
    var userId: UUID
    var imageURL: String
    var caption: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case groupId = "group_id"
        case userId = "user_id"
        case imageURL = "image_url"
        case caption
        case createdAt = "created_at"
    }
}
