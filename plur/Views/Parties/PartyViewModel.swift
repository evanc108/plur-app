import Foundation
import Supabase
import SwiftUI

struct PinnedItem: Identifiable {
    let id = UUID()
    var label: String
    var value: String
    var icon: String
}

@MainActor
@Observable
final class PartyViewModel {
    var parties: [RaveGroup] = []
    var members: [UUID: [GroupMember]] = [:]
    var messages: [UUID: [Message]] = [:]
    var photos: [UUID: [Photo]] = [:]
    var pinnedItems: [UUID: [PinnedItem]] = [:]

    /// Keyed by EDMTrain `rave_id`.
    var festivalScheduleByRaveId: [Int: EventScheduleRecord] = [:]
    var setSelectionsByGroup: [UUID: [SetSelection]] = [:]
    var scheduleLoadError: String?

    var isLoading = false
    var isUploadingPhoto = false
    var chatError: String?
    var photoError: String?
    var generalError: String?

    private var seenMessageIDs = Set<UUID>()

    var currentUserId: UUID?
    var currentUserDisplayName: String = ""

    private let service = PartyService()
    private let scheduleCache: ScheduleCacheStore

    init(scheduleCache: ScheduleCacheStore) {
        self.scheduleCache = scheduleCache
    }

    // MARK: - Loading

    func loadParties() async {
        isLoading = true
        generalError = nil
        do {
            let profile = try await service.fetchCurrentProfile()
            currentUserId = profile.id
            currentUserDisplayName = profile.displayName

            parties = try await service.fetchMyGroups()

            let allMembers = try await service.fetchAllMembers()
            members = Dictionary(grouping: allMembers) { $0.groupId }
        } catch {
            generalError = error.localizedDescription
        }
        isLoading = false
    }

    func loadMessages(for groupId: UUID) async {
        do {
            let fetched = try await service.fetchMessages(groupId: groupId)
            messages[groupId] = fetched
            for msg in fetched { seenMessageIDs.insert(msg.id) }
        } catch {
            chatError = error.localizedDescription
        }
    }

    /// Subscribe to new messages via Supabase Realtime. Blocks until the task is cancelled.
    func observeMessages(for groupId: UUID) async {
        let channel = SupabaseService.client.realtimeV2.channel("messages:\(groupId.uuidString)")
        let decoder = SupabaseJSONDecoder.shared

        let inserts = channel.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "messages",
            filter: "group_id=eq.\(groupId.uuidString)"
        )

        await channel.subscribe()

        for await insert in inserts {
            guard let message = try? insert.decodeRecord(as: Message.self, decoder: decoder) else { continue }
            if seenMessageIDs.insert(message.id).inserted {
                messages[groupId, default: []].append(message)
            }
        }

        await SupabaseService.client.realtimeV2.removeChannel(channel)
    }

    // MARK: - Invite

    func inviteLink(for party: RaveGroup) -> String {
        "https://plur.app/join/\(party.inviteCode)"
    }

    func searchUsers(query: String) async -> [AppUser] {
        guard !query.isEmpty, let userId = currentUserId else { return [] }
        do {
            return try await service.searchUsers(query: query, excludingUserId: userId)
        } catch {
            return []
        }
    }

    func inviteUser(_ user: AppUser, to partyID: UUID) async {
        do {
            try await service.inviteUser(userId: user.id, groupId: partyID)
            members[partyID] = try await service.fetchMembers(groupId: partyID)
        } catch {
            generalError = error.localizedDescription
        }
    }

    // MARK: - Join

    func joinPartyByLink(_ urlString: String) async -> Bool {
        let lowered = urlString.lowercased()
        guard let range = lowered.range(of: "plur.app/join/") else {
            return await joinParty(code: urlString)
        }
        let code = String(urlString[range.upperBound...])
        return await joinParty(code: code)
    }

    func joinParty(code: String) async -> Bool {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !trimmed.isEmpty else { return false }
        do {
            try await service.joinGroup(code: trimmed)
            await loadParties()
            return true
        } catch {
            return false
        }
    }

    // MARK: - Pin Sync

    func togglePin(messageID: UUID, in partyID: UUID) async {
        guard let idx = messages[partyID]?.firstIndex(where: { $0.id == messageID }) else { return }
        let newPinState = !messages[partyID]![idx].isPinned
        messages[partyID]![idx].isPinned = newPinState
        do {
            try await service.togglePin(messageId: messageID, isPinned: newPinState)
        } catch {
            messages[partyID]![idx].isPinned = !newPinState
            chatError = error.localizedDescription
        }
    }

    func pinnedMessages(for partyID: UUID) -> [Message] {
        messages[partyID]?.filter(\.isPinned) ?? []
    }

    // MARK: - Festival schedule (Supabase + SwiftData cache)

    func festivalSchedule(for party: RaveGroup) -> EventScheduleRecord? {
        festivalScheduleByRaveId[party.raveId]
    }

    func setSelections(for groupId: UUID) -> [SetSelection] {
        setSelectionsByGroup[groupId] ?? []
    }

    func isSlotSelected(_ slotId: UUID, groupId: UUID) -> Bool {
        guard let uid = currentUserId else { return false }
        return setSelections(for: groupId).contains { Self.matchesUserSlot($0, userId: uid, slotId: slotId) }
    }

    /// Up to three initials plus how many additional attendees selected this slot.
    func attendeeInitials(for slotId: UUID, groupId: UUID) -> (shown: [String], overflow: Int) {
        let selections = setSelections(for: groupId).filter { $0.slotId == slotId }
        let nameByUser = Dictionary(uniqueKeysWithValues: (members[groupId] ?? []).map { ($0.userId, $0.displayName) })
        let initials = selections.map { Self.initials(from: nameByUser[$0.userId] ?? "?") }
        let maxShow = 3
        if initials.count <= maxShow { return (initials, 0) }
        return (Array(initials.prefix(maxShow)), initials.count - maxShow)
    }

    func loadScheduleData(for party: RaveGroup) async {
        let rid = party.raveId
        let gid = party.id
        scheduleLoadError = nil

        if rid != 0, let cached = try? scheduleCache.cachedSchedule(raveId: rid) {
            festivalScheduleByRaveId[rid] = cached.normalized()
        }
        if let cachedSel = try? scheduleCache.cachedSelections(groupId: gid) {
            setSelectionsByGroup[gid] = cachedSel
        }

        guard rid != 0 else { return }

        do {
            if let remote = try await service.fetchEventSchedule(raveId: rid) {
                festivalScheduleByRaveId[rid] = remote
                try? scheduleCache.saveSchedule(remote)
            } else {
                festivalScheduleByRaveId[rid] = nil
            }
            let remoteSel = try await service.fetchSetSelections(groupId: gid)
            setSelectionsByGroup[gid] = remoteSel
            try? scheduleCache.saveSelections(remoteSel, groupId: gid)
        } catch {
            scheduleLoadError = error.localizedDescription
        }
    }

    func toggleSlotSelection(_ slotId: UUID, in party: RaveGroup) async {
        let gid = party.id
        guard let uid = currentUserId else { return }
        let previous = setSelectionsByGroup[gid] ?? []
        let wasSelected = previous.contains { Self.matchesUserSlot($0, userId: uid, slotId: slotId) }

        if wasSelected {
            setSelectionsByGroup[gid] = previous.filter { !Self.matchesUserSlot($0, userId: uid, slotId: slotId) }
        } else {
            var next = previous
            next.append(SetSelection(id: UUID(), userId: uid, groupId: gid, slotId: slotId, createdAt: Date()))
            setSelectionsByGroup[gid] = next
        }
        cacheSelectionsToDisk(for: gid)

        do {
            if wasSelected {
                try await service.deleteSetSelection(groupId: gid, slotId: slotId)
            } else {
                let inserted = try await service.insertSetSelection(groupId: gid, slotId: slotId)
                var next = setSelectionsByGroup[gid] ?? []
                if let i = next.firstIndex(where: { Self.matchesUserSlot($0, userId: uid, slotId: slotId) }) {
                    next[i] = inserted
                }
                setSelectionsByGroup[gid] = next
                cacheSelectionsToDisk(for: gid)
            }
        } catch {
            setSelectionsByGroup[gid] = previous
            try? scheduleCache.saveSelections(previous, groupId: gid)
            generalError = error.localizedDescription
        }
    }

    private func cacheSelectionsToDisk(for groupId: UUID) {
        try? scheduleCache.saveSelections(setSelectionsByGroup[groupId] ?? [], groupId: groupId)
    }

    private static func matchesUserSlot(_ selection: SetSelection, userId: UUID, slotId: UUID) -> Bool {
        selection.userId == userId && selection.slotId == slotId
    }

    private static func initials(from displayName: String) -> String {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: " ").filter { !$0.isEmpty }
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        if trimmed.count >= 2 {
            return String(trimmed.prefix(2)).uppercased()
        }
        return String(trimmed.prefix(1)).uppercased()
    }

    // MARK: - Send Message

    func sendMessage(content: String, in partyID: UUID) async -> Bool {
        guard !content.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        chatError = nil
        do {
            let msg = try await service.sendMessage(
                groupId: partyID,
                content: content,
                senderName: currentUserDisplayName
            )
            seenMessageIDs.insert(msg.id)
            messages[partyID, default: []].append(msg)
            return true
        } catch {
            chatError = error.localizedDescription
            return false
        }
    }

    // MARK: - Photos

    func loadPhotos(for groupId: UUID) async {
        do {
            photos[groupId] = try await service.fetchPhotos(groupId: groupId)
        } catch {
            photoError = error.localizedDescription
        }
    }

    func uploadPhoto(to groupId: UUID, imageData: Data, caption: String?) async -> Bool {
        isUploadingPhoto = true
        defer { isUploadingPhoto = false }
        do {
            let photo = try await service.uploadPhoto(groupId: groupId, imageData: imageData, caption: caption)
            var list = photos[groupId] ?? []
            list.insert(photo, at: 0)
            photos[groupId] = list
            return true
        } catch {
            photoError = error.localizedDescription
            return false
        }
    }

    func deletePhoto(_ photo: Photo, in groupId: UUID) async {
        let pathComponents = photo.imageURL.components(separatedBy: "/party-photos/")
        let storagePath = pathComponents.count > 1 ? pathComponents[1] : "\(groupId.uuidString)/\(photo.id.uuidString).jpg"
        do {
            try await service.deletePhoto(photoId: photo.id, storagePath: storagePath)
            var list = photos[groupId] ?? []
            list.removeAll { $0.id == photo.id }
            photos[groupId] = list
        } catch {
            photoError = error.localizedDescription
        }
    }

    // MARK: - Create

    func createParty(
        name: String,
        eventName: String,
        raveId: Int,
        venue: String,
        startDate: Date,
        endDate: Date,
        playlistLink: String?
    ) async -> Bool {
        do {
            try await service.createGroup(
                name: name,
                eventName: eventName,
                raveId: raveId,
                venue: venue,
                startDate: startDate,
                endDate: endDate,
                playlistLink: playlistLink
            )
            await loadParties()
            return true
        } catch {
            generalError = error.localizedDescription
            return false
        }
    }
}
