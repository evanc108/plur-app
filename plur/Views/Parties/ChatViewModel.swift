import Foundation
import Supabase

@MainActor
@Observable
final class ChatViewModel {
    var messages: [UUID: [Message]] = [:]
    var chatError: String?

    private var seenMessageIDs = Set<UUID>()
    private let service = ChatService()

    // MARK: - Loading

    func loadMessages(for groupId: UUID) async {
        do {
            let fetched = try await service.fetchMessages(groupId: groupId)
            messages[groupId] = fetched
            for msg in fetched { seenMessageIDs.insert(msg.id) }
        } catch {
            chatError = error.localizedDescription
        }
    }

    func observeMessages(for groupId: UUID) async {
        let channel = SupabaseService.client.realtimeV2.channel("messages:\(groupId.uuidString)")
        let decoder = SupabaseJSONDecoder.shared

        let inserts = channel.postgresChange(
            InsertAction.self,
            table: "messages",
            filter: .eq("group_id", value: groupId)
        )

        try? await channel.subscribeWithError()

        for await insert in inserts {
            guard let message = try? insert.decodeRecord(as: Message.self, decoder: decoder) else { continue }
            if seenMessageIDs.insert(message.id).inserted {
                messages[groupId, default: []].append(message)
            }
        }

        await SupabaseService.client.realtimeV2.removeChannel(channel)
    }

    // MARK: - Send

    func sendMessage(content: String, in groupId: UUID, userId: UUID, displayName: String) async -> Bool {
        guard !content.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        chatError = nil
        do {
            let msg = try await service.sendMessage(
                groupId: groupId,
                userId: userId,
                content: content,
                senderName: displayName
            )
            seenMessageIDs.insert(msg.id)
            messages[groupId, default: []].append(msg)
            return true
        } catch {
            chatError = error.localizedDescription
            return false
        }
    }

    // MARK: - Pin

    func togglePin(messageID: UUID, in groupId: UUID) async {
        guard let idx = messages[groupId]?.firstIndex(where: { $0.id == messageID }) else { return }
        let newPinState = !messages[groupId]![idx].isPinned
        messages[groupId]![idx].isPinned = newPinState
        do {
            try await service.togglePin(messageId: messageID, isPinned: newPinState)
        } catch {
            messages[groupId]![idx].isPinned = !newPinState
            chatError = error.localizedDescription
        }
    }

    func pinnedMessages(for groupId: UUID) -> [Message] {
        messages[groupId]?.filter(\.isPinned) ?? []
    }
}
