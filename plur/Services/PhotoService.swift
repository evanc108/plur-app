import Foundation
import Supabase

// MARK: - DTOs

private struct NewPhoto: Encodable, Sendable {
    let group_id: UUID
    let user_id: UUID
    let image_url: String
    let caption: String?
}

// MARK: - Service

struct PhotoService: Sendable {
    private let client = SupabaseService.client

    func fetchPhotos(groupId: UUID) async throws -> [Photo] {
        try await client.from("photos")
            .select()
            .eq("group_id", value: groupId)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    func uploadPhoto(groupId: UUID, userId: UUID, imageData: Data, caption: String?) async throws -> Photo {
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
        try await client.from("photos")
            .delete()
            .eq("id", value: photoId)
            .execute()
        try await client.storage.from("party-photos")
            .remove(paths: [storagePath])
    }
}
