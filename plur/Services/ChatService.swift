import Foundation
import Supabase

// MARK: - DTOs

private struct NewMessage: Encodable, Sendable {
    let group_id: UUID
    let user_id: UUID
    let sender_name: String
    let content: String
}

private struct PinUpdate: Encodable, Sendable {
    let is_pinned: Bool
}

// MARK: - Service

struct ChatService: Sendable {
    private let client = SupabaseService.client

    func fetchMessages(groupId: UUID) async throws -> [Message] {
        try await client.from("messages")
            .select()
            .eq("group_id", value: groupId)
            .order("created_at")
            .execute()
            .value
    }

    func sendMessage(groupId: UUID, userId: UUID, content: String, senderName: String) async throws -> Message {
        try await client.from("messages")
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
}
