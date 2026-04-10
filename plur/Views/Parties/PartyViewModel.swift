import Foundation
import SwiftUI

struct PinnedItem: Identifiable, Hashable {
    var label: String
    var value: String
    var icon: String

    var id: String { "\(label):\(value)" }
}

@MainActor
@Observable
final class PartyViewModel {
    var parties: [RaveGroup] = []
    var members: [UUID: [GroupMember]] = [:]
    var pinnedItems: [UUID: [PinnedItem]] = [:]

    var isLoading = false
    var generalError: String?

    var currentUserId: UUID?
    var currentUserDisplayName: String = ""

    private let groupService = GroupService()
    private let profileService = ProfileService()

    // MARK: - Loading

    func loadParties() async {
        isLoading = true
        generalError = nil
        do {
            let profile = try await profileService.fetchCurrentProfile()
            currentUserId = profile.id
            currentUserDisplayName = profile.displayName

            parties = try await groupService.fetchMyGroups()

            let allMembers = try await groupService.fetchAllMembers()
            members = Dictionary(grouping: allMembers) { $0.groupId }
        } catch {
            generalError = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Invite

    func inviteLink(for party: RaveGroup) -> String {
        "https://plur.app/join/\(party.inviteCode)"
    }

    func searchUsers(query: String) async -> [AppUser] {
        guard !query.isEmpty, let userId = currentUserId else { return [] }
        do {
            return try await profileService.searchUsers(query: query, excludingUserId: userId)
        } catch {
            return []
        }
    }

    func inviteUser(_ user: AppUser, to partyID: UUID) async {
        do {
            try await groupService.inviteUser(userId: user.id, groupId: partyID)
            members[partyID] = try await groupService.fetchMembers(groupId: partyID)
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
            try await groupService.joinGroup(code: trimmed)
            await loadParties()
            return true
        } catch {
            return false
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
            try await groupService.createGroup(
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
