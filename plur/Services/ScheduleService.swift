import Foundation
import Supabase

// MARK: - DTOs

private struct NewSetSelection: Encodable, Sendable {
    let group_id: UUID
    let user_id: UUID
    let slot_id: UUID
}

// MARK: - Service

struct ScheduleService: Sendable {
    private let client = SupabaseService.client

    func fetchEventSchedule(raveId: Int) async throws -> EventScheduleRecord? {
        guard raveId != 0 else { return nil }
        let rows: [EventScheduleRecord] = try await client.from("event_schedules")
            .select("*, schedule_days(*), schedule_stages(*), schedule_slots(*)")
            .eq("rave_id", value: raveId)
            .limit(1)
            .execute()
            .value
        return rows.first.map { $0.normalized() }
    }

    func fetchSetSelections(groupId: UUID) async throws -> [SetSelection] {
        try await client.from("set_selections")
            .select()
            .eq("group_id", value: groupId)
            .execute()
            .value
    }

    func insertSetSelection(groupId: UUID, userId: UUID, slotId: UUID) async throws -> SetSelection {
        try await client.from("set_selections")
            .insert(NewSetSelection(group_id: groupId, user_id: userId, slot_id: slotId))
            .select()
            .single()
            .execute()
            .value
    }

    func deleteSetSelection(groupId: UUID, userId: UUID, slotId: UUID) async throws {
        try await client.from("set_selections")
            .delete()
            .eq("group_id", value: groupId)
            .eq("user_id", value: userId)
            .eq("slot_id", value: slotId)
            .execute()
    }
}
