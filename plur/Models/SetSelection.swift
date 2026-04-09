import Foundation

struct SetSelection: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var userId: UUID
    var groupId: UUID
    var slotId: UUID
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case groupId = "group_id"
        case slotId = "slot_id"
        case createdAt = "created_at"
    }
}
