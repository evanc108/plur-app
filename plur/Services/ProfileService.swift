import Foundation
import Supabase

struct ProfileService: Sendable {
    private let client = SupabaseService.client

    func currentUserId() async throws -> UUID {
        try await client.auth.session.user.id
    }

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
        let sanitized = query
            .replacingOccurrences(of: "%", with: "")
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !sanitized.isEmpty else { return [] }

        return try await client.from("profiles")
            .select()
            .or("username.ilike.%\(sanitized)%,display_name.ilike.%\(sanitized)%")
            .neq("id", value: excludingUserId)
            .limit(20)
            .execute()
            .value
    }
}
