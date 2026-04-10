import Foundation

@MainActor
@Observable
final class PhotosViewModel {
    var photos: [UUID: [Photo]] = [:]
    var isUploadingPhoto = false
    var photoError: String?

    private let service = PhotoService()

    func loadPhotos(for groupId: UUID) async {
        do {
            photos[groupId] = try await service.fetchPhotos(groupId: groupId)
        } catch {
            photoError = error.localizedDescription
        }
    }

    func uploadPhoto(to groupId: UUID, userId: UUID, imageData: Data, caption: String?) async -> Bool {
        isUploadingPhoto = true
        defer { isUploadingPhoto = false }
        do {
            let photo = try await service.uploadPhoto(
                groupId: groupId,
                userId: userId,
                imageData: imageData,
                caption: caption
            )
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
}
