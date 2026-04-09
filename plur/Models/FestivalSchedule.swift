import Foundation

// MARK: - API / domain (Supabase nested select)

struct EventScheduleRecord: Codable, Identifiable, Sendable {
    let id: UUID
    let raveId: Int
    let timezone: String
    let createdAt: Date?
    var scheduleDays: [ScheduleDayRecord]?
    var scheduleStages: [ScheduleStageRecord]?
    var scheduleSlots: [ScheduleSlotRecord]?

    enum CodingKeys: String, CodingKey {
        case id
        case raveId = "rave_id"
        case timezone
        case createdAt = "created_at"
        case scheduleDays = "schedule_days"
        case scheduleStages = "schedule_stages"
        case scheduleSlots = "schedule_slots"
    }

    /// Sorted days, stages, slots for UI.
    func normalized() -> EventScheduleRecord {
        var copy = self
        copy.scheduleDays = (scheduleDays ?? []).sorted { $0.dayIndex < $1.dayIndex }
        copy.scheduleStages = (scheduleStages ?? []).sorted { $0.sortOrder < $1.sortOrder }
        copy.scheduleSlots = (scheduleSlots ?? []).sorted {
            if $0.startAt != $1.startAt { return $0.startAt < $1.startAt }
            return $0.title < $1.title
        }
        return copy
    }
}

struct ScheduleDayRecord: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let scheduleId: UUID
    let dayIndex: Int
    let label: String

    enum CodingKeys: String, CodingKey {
        case id
        case scheduleId = "schedule_id"
        case dayIndex = "day_index"
        case label
    }
}

struct ScheduleStageRecord: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let scheduleId: UUID
    let name: String
    let sortOrder: Int
    let accentColor: String?

    enum CodingKeys: String, CodingKey {
        case id
        case scheduleId = "schedule_id"
        case name
        case sortOrder = "sort_order"
        case accentColor = "accent_color"
    }
}

struct ScheduleSlotRecord: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let scheduleId: UUID
    let dayId: UUID
    let stageId: UUID
    let title: String
    let startAt: Date
    let endAt: Date
    let edmtrainArtistId: Int?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case scheduleId = "schedule_id"
        case dayId = "day_id"
        case stageId = "stage_id"
        case title
        case startAt = "start_at"
        case endAt = "end_at"
        case edmtrainArtistId = "edmtrain_artist_id"
        case createdAt = "created_at"
    }
}
