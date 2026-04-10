import Foundation

struct RaveGroup: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var name: String
    var raveId: Int
    var createdBy: UUID
    var inviteCode: String
    var eventName: String
    var venue: String
    var startDate: Date
    var endDate: Date
    var playlistLink: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name, venue
        case raveId = "rave_id"
        case createdBy = "created_by"
        case inviteCode = "invite_code"
        case eventName = "event_name"
        case startDate = "start_date"
        case endDate = "end_date"
        case playlistLink = "playlist_link"
        case createdAt = "created_at"
    }

    var isPast: Bool {
        endDate < Date()
    }

    private static let shortDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "MMM d"
        return f
    }()

    private static let yearDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "MMM d, yyyy"
        return f
    }()

    var dateRangeText: String {
        let start = Self.shortDateFormatter.string(from: startDate)
        let end = Self.yearDateFormatter.string(from: endDate)
        return "\(start)–\(end)"
    }
}

enum RSVPStatus: String, Codable, CaseIterable, Sendable {
    case going
    case maybe
    case invited

    var label: String {
        rawValue.capitalized
    }

    var icon: String {
        switch self {
        case .going: "checkmark.circle.fill"
        case .maybe: "questionmark.circle.fill"
        case .invited: "envelope.circle.fill"
        }
    }
}

struct GroupMember: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var groupId: UUID
    var userId: UUID
    var role: GroupRole
    var rsvpStatus: RSVPStatus
    var displayName: String
    let joinedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, role
        case groupId = "group_id"
        case userId = "user_id"
        case rsvpStatus = "rsvp_status"
        case displayName = "display_name"
        case joinedAt = "joined_at"
    }
}

enum GroupRole: String, Codable, Sendable {
    case owner
    case admin
    case member
}
