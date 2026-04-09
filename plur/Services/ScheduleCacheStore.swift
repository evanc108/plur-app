import Foundation
import SwiftData

@Model
final class CachedFestivalSchedulePayload {
    @Attribute(.unique) var raveId: Int
    var jsonData: Data
    var lastSyncedAt: Date

    init(raveId: Int, jsonData: Data, lastSyncedAt: Date) {
        self.raveId = raveId
        self.jsonData = jsonData
        self.lastSyncedAt = lastSyncedAt
    }
}

@Model
final class CachedSetSelectionsPayload {
    @Attribute(.unique) var groupId: UUID
    var jsonData: Data
    var lastSyncedAt: Date

    init(groupId: UUID, jsonData: Data, lastSyncedAt: Date) {
        self.groupId = groupId
        self.jsonData = jsonData
        self.lastSyncedAt = lastSyncedAt
    }
}

@MainActor
final class ScheduleCacheStore {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func cachedSchedule(raveId: Int) throws -> EventScheduleRecord? {
        guard raveId != 0 else { return nil }
        let desc = FetchDescriptor<CachedFestivalSchedulePayload>(
            predicate: #Predicate { $0.raveId == raveId }
        )
        guard let row = try modelContext.fetch(desc).first else { return nil }
        return try SupabaseJSONDecoder.shared.decode(EventScheduleRecord.self, from: row.jsonData)
    }

    func saveSchedule(_ record: EventScheduleRecord) throws {
        let data = try SupabaseJSONEncoder.shared.encode(record)
        try upsertSchedule(raveId: record.raveId, jsonData: data)
    }

    func cachedSelections(groupId: UUID) throws -> [SetSelection] {
        let desc = FetchDescriptor<CachedSetSelectionsPayload>(
            predicate: #Predicate { $0.groupId == groupId }
        )
        guard let row = try modelContext.fetch(desc).first else { return [] }
        return try SupabaseJSONDecoder.shared.decode([SetSelection].self, from: row.jsonData)
    }

    func saveSelections(_ items: [SetSelection], groupId: UUID) throws {
        let data = try SupabaseJSONEncoder.shared.encode(items)
        try upsertSelections(groupId: groupId, jsonData: data)
    }

    private func upsertSchedule(raveId: Int, jsonData: Data) throws {
        let desc = FetchDescriptor<CachedFestivalSchedulePayload>(
            predicate: #Predicate { $0.raveId == raveId }
        )
        let now = Date()
        if let existing = try modelContext.fetch(desc).first {
            existing.jsonData = jsonData
            existing.lastSyncedAt = now
        } else {
            modelContext.insert(CachedFestivalSchedulePayload(raveId: raveId, jsonData: jsonData, lastSyncedAt: now))
        }
        try modelContext.save()
    }

    private func upsertSelections(groupId: UUID, jsonData: Data) throws {
        let desc = FetchDescriptor<CachedSetSelectionsPayload>(
            predicate: #Predicate { $0.groupId == groupId }
        )
        let now = Date()
        if let existing = try modelContext.fetch(desc).first {
            existing.jsonData = jsonData
            existing.lastSyncedAt = now
        } else {
            modelContext.insert(CachedSetSelectionsPayload(groupId: groupId, jsonData: jsonData, lastSyncedAt: now))
        }
        try modelContext.save()
    }
}
