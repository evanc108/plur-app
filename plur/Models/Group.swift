import Foundation

struct RaveGroup: Codable, Identifiable {
    let id: UUID
    var name: String
    var raveId: Int
    var createdBy: UUID
    var inviteCode: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case raveId = "rave_id"
        case createdBy = "created_by"
        case inviteCode = "invite_code"
        case createdAt = "created_at"
    }
}

struct GroupMember: Codable, Identifiable {
    let id: UUID
    var groupId: UUID
    var userId: UUID
    var role: GroupRole
    let joinedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case groupId = "group_id"
        case userId = "user_id"
        case role
        case joinedAt = "joined_at"
    }
}

enum GroupRole: String, Codable {
    case owner
    case admin
    case member
}
