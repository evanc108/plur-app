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
    var artists: [UUID: [Artist]] = [:]
    var savedArtistIDs: Set<Int> = []
    var friendArtistMap: [Int: String] = [:]

    var showConflictAlert = false
    var conflictMessage = ""
    var pendingArtistID: Int?
    var pendingPartyID: UUID?

    var isLoading = false
    var isUploadingPhoto = false
    var error: String?

    var currentUserId: UUID?
    var currentUserDisplayName: String = ""

    private let service = PartyService()

    // MARK: - Loading

    func loadParties() async {
        isLoading = true
        error = nil
        do {
            let profile = try await service.fetchCurrentProfile()
            currentUserId = profile.id
            currentUserDisplayName = profile.displayName

            parties = try await service.fetchMyGroups()

            let allMembers = try await service.fetchAllMembers()
            members = Dictionary(grouping: allMembers) { $0.groupId }
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func loadMessages(for groupId: UUID) async {
        do {
            messages[groupId] = try await service.fetchMessages(groupId: groupId)
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Subscribe to new messages via Supabase Realtime. Blocks until the task is cancelled.
    func observeMessages(for groupId: UUID) async {
        let channel = SupabaseService.client.realtimeV2.channel("messages:\(groupId.uuidString)")
        let decoder = Self.supabaseDecoder

        let inserts = channel.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "messages",
            filter: "group_id=eq.\(groupId.uuidString)"
        )

        await channel.subscribe()

        for await insert in inserts {
            guard let message = try? insert.decodeRecord(as: Message.self, decoder: decoder) else { continue }
            if !(messages[groupId]?.contains(where: { $0.id == message.id }) ?? false) {
                messages[groupId, default: []].append(message)
            }
        }

        await SupabaseService.client.realtimeV2.removeChannel(channel)
    }

    private static let supabaseDecoder: JSONDecoder = {
        let decoder = JSONDecoder()

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        let isoFrac = ISO8601DateFormatter()
        isoFrac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            if let date = isoFrac.date(from: value) ?? iso.date(from: value) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ISO8601 date: \(value)")
        }

        return decoder
    }()

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
            self.error = error.localizedDescription
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
            self.error = error.localizedDescription
        }
    }

    func pinnedMessages(for partyID: UUID) -> [Message] {
        messages[partyID]?.filter(\.isPinned) ?? []
    }

    // MARK: - Schedule (local — not DB-backed yet)

    func artistsByStage(for partyID: UUID) -> [(stage: String, artists: [Artist])] {
        guard let all = artists[partyID] else { return [] }
        let grouped = Dictionary(grouping: all) { $0.stage ?? "Other" }
        let stageOrder = ["Kinetic Field", "Circuit Grounds", "Cosmic Meadow"]
        return stageOrder.compactMap { stage in
            guard let list = grouped[stage] else { return nil }
            return (stage: stage, artists: list.sorted { ($0.startTime ?? .distantPast) < ($1.startTime ?? .distantPast) })
        }
    }

    func isArtistSaved(_ artistID: Int) -> Bool {
        savedArtistIDs.contains(artistID)
    }

    func toggleArtist(_ artist: Artist, in partyID: UUID) {
        if savedArtistIDs.contains(artist.id) {
            savedArtistIDs.remove(artist.id)
            return
        }

        if let conflict = findConflict(for: artist, in: partyID) {
            pendingArtistID = artist.id
            pendingPartyID = partyID
            conflictMessage = "'\(artist.name)' overlaps with '\(conflict.name)'. Save anyway?"
            showConflictAlert = true
        } else {
            savedArtistIDs.insert(artist.id)
        }
    }

    func confirmPendingArtist() {
        if let id = pendingArtistID {
            savedArtistIDs.insert(id)
        }
        pendingArtistID = nil
        pendingPartyID = nil
    }

    private func findConflict(for artist: Artist, in partyID: UUID) -> Artist? {
        guard let start = artist.startTime, let end = artist.endTime,
              let allArtists = artists[partyID] else { return nil }

        return allArtists.first { other in
            guard other.id != artist.id,
                  savedArtistIDs.contains(other.id),
                  let otherStart = other.startTime,
                  let otherEnd = other.endTime else { return false }
            return start < otherEnd && end > otherStart
        }
    }

    // MARK: - Send Message

    func sendMessage(content: String, in partyID: UUID) async -> Bool {
        guard !content.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        error = nil
        do {
            let msg = try await service.sendMessage(
                groupId: partyID,
                content: content,
                senderName: currentUserDisplayName
            )
            messages[partyID, default: []].append(msg)
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    // MARK: - Photos

    func loadPhotos(for groupId: UUID) async {
        do {
            photos[groupId] = try await service.fetchPhotos(groupId: groupId)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func uploadPhoto(to groupId: UUID, imageData: Data, caption: String?) async -> Bool {
        isUploadingPhoto = true
        defer { isUploadingPhoto = false }
        do {
            let photo = try await service.uploadPhoto(groupId: groupId, imageData: imageData, caption: caption)
            photos[groupId, default: []].insert(photo, at: 0)
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    func deletePhoto(_ photo: Photo, in groupId: UUID) async {
        let pathComponents = photo.imageURL.components(separatedBy: "/party-photos/")
        let storagePath = pathComponents.count > 1 ? pathComponents[1] : "\(groupId.uuidString)/\(photo.id.uuidString).jpg"
        do {
            try await service.deletePhoto(photoId: photo.id, storagePath: storagePath)
            photos[groupId]?.removeAll { $0.id == photo.id }
        } catch {
            self.error = error.localizedDescription
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
            self.error = error.localizedDescription
            return false
        }
    }
}
