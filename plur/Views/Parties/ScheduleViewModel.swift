import Foundation

@MainActor
@Observable
final class ScheduleViewModel {
    var festivalScheduleByRaveId: [Int: EventScheduleRecord] = [:]
    var setSelectionsByGroup: [UUID: [SetSelection]] = [:]
    var scheduleLoadError: String?
    var generalError: String?

    private let service = ScheduleService()
    private let scheduleCache: ScheduleCacheStore

    init(scheduleCache: ScheduleCacheStore) {
        self.scheduleCache = scheduleCache
    }

    // MARK: - Accessors

    func festivalSchedule(for party: RaveGroup) -> EventScheduleRecord? {
        festivalScheduleByRaveId[party.raveId]
    }

    func setSelections(for groupId: UUID) -> [SetSelection] {
        setSelectionsByGroup[groupId] ?? []
    }

    func isSlotSelected(_ slotId: UUID, groupId: UUID, userId: UUID?) -> Bool {
        guard let uid = userId else { return false }
        return setSelections(for: groupId).contains { Self.matchesUserSlot($0, userId: uid, slotId: slotId) }
    }

    func attendeeInitials(for slotId: UUID, groupId: UUID, members: [GroupMember]) -> (shown: [String], overflow: Int) {
        let selections = setSelections(for: groupId).filter { $0.slotId == slotId }
        let nameByUser = Dictionary(uniqueKeysWithValues: members.map { ($0.userId, $0.displayName) })
        let initials = selections.map { Self.initials(from: nameByUser[$0.userId] ?? "?") }
        let maxShow = 3
        if initials.count <= maxShow { return (initials, 0) }
        return (Array(initials.prefix(maxShow)), initials.count - maxShow)
    }

    // MARK: - Loading

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

    // MARK: - Toggle

    func toggleSlotSelection(_ slotId: UUID, in party: RaveGroup, userId: UUID?) async {
        let gid = party.id
        guard let uid = userId else { return }
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
                try await service.deleteSetSelection(groupId: gid, userId: uid, slotId: slotId)
            } else {
                let inserted = try await service.insertSetSelection(groupId: gid, userId: uid, slotId: slotId)
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

    // MARK: - Private

    private func cacheSelectionsToDisk(for groupId: UUID) {
        try? scheduleCache.saveSelections(setSelectionsByGroup[groupId] ?? [], groupId: groupId)
    }

    private static func matchesUserSlot(_ selection: SetSelection, userId: UUID, slotId: UUID) -> Bool {
        selection.userId == userId && selection.slotId == slotId
    }

    static func initials(from displayName: String) -> String {
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
}
