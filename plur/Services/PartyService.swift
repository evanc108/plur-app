import Foundation
import Supabase

// MARK: - RPC Parameter DTOs

private struct CreateGroupParams: @preconcurrency Encodable, Sendable {
    let p_name: String
    let p_event_name: String
    let p_rave_id: Int
    let p_venue: String
    let p_start_date: Date
    let p_end_date: Date
    let p_playlist_link: String?
}

private struct JoinGroupParams: @preconcurrency Encodable, Sendable {
    let p_code: String
}

private struct InviteParams: @preconcurrency Encodable, Sendable {
    let p_group_id: UUID
    let p_user_id: UUID
}

private struct NewMessage: @preconcurrency Encodable, Sendable {
    let group_id: UUID
    let user_id: UUID
    let sender_name: String
    let content: String
}

private struct PinUpdate: @preconcurrency Encodable, Sendable {
    let is_pinned: Bool
}

private struct NewPhoto: @preconcurrency Encodable, Sendable {
    let group_id: UUID
    let user_id: UUID
    let image_url: String
    let caption: String?
}

// MARK: - Service

struct PartyService: Sendable {
    private let client = SupabaseService.client

    private func currentUserId() async throws -> UUID {
        try await client.auth.session.user.id
    }

    // MARK: - Profiles

    func fetchCurrentProfile() async throws -> AppUser {
        let id = try await currentUserId()
        return try await client.from("profiles")
            .select()
            .eq("id", value: id)
            .single()
            .execute()
            .value
    }

    func searchUsers(query: String, excludingUserId: UUID) async throws -> [AppUser] {
        try await client.from("profiles")
            .select()
            .or("username.ilike.%\(query)%,display_name.ilike.%\(query)%")
            .neq("id", value: excludingUserId)
            .limit(20)
            .execute()
            .value
    }

    // MARK: - Groups

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

    // MARK: - Members

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

    // MARK: - Messages

    func fetchMessages(groupId: UUID) async throws -> [Message] {
        try await client.from("messages")
            .select()
            .eq("group_id", value: groupId)
            .order("created_at")
            .execute()
            .value
    }

    func sendMessage(groupId: UUID, content: String, senderName: String) async throws -> Message {
        let userId = try await currentUserId()
        return try await client.from("messages")
            .insert(
                NewMessage(
                    group_id: groupId,
                    user_id: userId,
                    sender_name: senderName,
                    content: content
                )
            )
            .select()
            .single()
            .execute()
            .value
    }

    func togglePin(messageId: UUID, isPinned: Bool) async throws {
        try await client.from("messages")
            .update(PinUpdate(is_pinned: isPinned))
            .eq("id", value: messageId)
            .execute()
    }

    // MARK: - Photos

    func fetchPhotos(groupId: UUID) async throws -> [Photo] {
        try await client.from("photos")
            .select()
            .eq("group_id", value: groupId)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    /// Uploads JPEG data to Supabase Storage and inserts a row into `photos`.
    func uploadPhoto(groupId: UUID, imageData: Data, caption: String?) async throws -> Photo {
        let userId = try await currentUserId()
        let filename = "\(UUID().uuidString).jpg"
        let storagePath = "\(groupId.uuidString)/\(filename)"

        try await client.storage.from("party-photos")
            .upload(storagePath, data: imageData, options: .init(contentType: "image/jpeg"))

        let publicURL = try client.storage.from("party-photos")
            .getPublicURL(path: storagePath)
            .absoluteString

        return try await client.from("photos")
            .insert(NewPhoto(
                group_id: groupId,
                user_id: userId,
                image_url: publicURL,
                caption: caption
            ))
            .select()
            .single()
            .execute()
            .value
    }

    func deletePhoto(photoId: UUID, storagePath: String) async throws {
        try await client.storage.from("party-photos")
            .remove(paths: [storagePath])
        try await client.from("photos")
            .delete()
            .eq("id", value: photoId)
            .execute()
    }
}
