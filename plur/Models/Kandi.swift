import Foundation

struct Kandi: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var fromUserId: UUID
    var toUserId: UUID
    var message: String?
    var imageURL: String?
    var raveId: Int?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case fromUserId = "from_user_id"
        case toUserId = "to_user_id"
        case message
        case imageURL = "image_url"
        case raveId = "rave_id"
        case createdAt = "created_at"
    }
}
