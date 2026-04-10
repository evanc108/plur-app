import Foundation
import Supabase

// MARK: - RPC Parameter DTOs

private struct CreateGroupParams: Encodable, Sendable {
    let p_name: String
    let p_event_name: String
    let p_rave_id: Int
    let p_venue: String
    let p_start_date: Date
    let p_end_date: Date
    let p_playlist_link: String?
}

private struct JoinGroupParams: Encodable, Sendable {
    let p_code: String
}

private struct InviteParams: Encodable, Sendable {
    let p_group_id: UUID
    let p_user_id: UUID
}

// MARK: - Service

struct GroupService: Sendable {
    private let client = SupabaseService.client

    func fetchMyGroups() async throws -> [RaveGroup] {
        try await client.from("groups")
            .select()
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    func createGroup(
        name: String,
        eventName: String,
        raveId: Int,
        venue: String,
        startDate: Date,
        endDate: Date,
        playlistLink: String?
    ) async throws {
        try await client.rpc(
            "create_group",
            params: CreateGroupParams(
                p_name: name,
                p_event_name: eventName,
                p_rave_id: raveId,
                p_venue: venue,
                p_start_date: startDate,
                p_end_date: endDate,
                p_playlist_link: playlistLink
            )
        ).execute()
    }

    func joinGroup(code: String) async throws {
        try await client.rpc(
            "join_group_by_code",
            params: JoinGroupParams(p_code: code)
        ).execute()
    }

    func fetchAllMembers() async throws -> [GroupMember] {
        try await client.from("group_members")
            .select()
            .execute()
            .value
    }

    func fetchMembers(groupId: UUID) async throws -> [GroupMember] {
        try await client.from("group_members")
            .select()
            .eq("group_id", value: groupId)
            .execute()
            .value
    }

    func inviteUser(userId: UUID, groupId: UUID) async throws {
        try await client.rpc(
            "invite_to_group",
            params: InviteParams(p_group_id: groupId, p_user_id: userId)
        ).execute()
    }
}
