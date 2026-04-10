import CoreTransferable
import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

private enum PickedImageTransferError: Error {
    case importFailed
}

private struct PickedImageData: Transferable {
    let data: Data

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(importedContentType: UTType.image) { data in
            guard UIImage(data: data) != nil else {
                throw PickedImageTransferError.importFailed
            }
            return PickedImageData(data: data)
        }
    }
}

struct PhotosView: View {
    let party: RaveGroup
    let partyVM: PartyViewModel
    @Bindable var photosVM: PhotosViewModel

    @State private var selectedPickerItems: [PhotosPickerItem] = []
    @State private var isCompressing = false
    @State private var isBatchActive = false
    @State private var fullscreenPhoto: Photo?
    @State private var pickErrorMessage: String?

    private var photos: [Photo] {
        photosVM.photos[party.id] ?? []
    }

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
    ]

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                if photos.isEmpty && !photosVM.isUploadingPhoto && !isBatchActive {
                    emptyState
                } else {
                    photoGrid
                }
                uploadBar
            }

            if let photo = fullscreenPhoto {
                fullscreenOverlay(photo)
            }
        }
        .background(Color.plurVoid)
        .task {
            await photosVM.loadPhotos(for: party.id)
        }
        .onChange(of: selectedPickerItems) { _, items in
            guard !items.isEmpty else { return }
            let toProcess = items
            Task { @MainActor in
                await handlePickedItems(toProcess)
            }
        }
        .alert("Couldn't add photos", isPresented: Binding(
            get: { pickErrorMessage != nil },
            set: { if !$0 { pickErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { pickErrorMessage = nil }
        } message: {
            Text(pickErrorMessage ?? "")
        }
        .alert("Upload failed", isPresented: Binding(
            get: { photosVM.photoError != nil },
            set: { if !$0 { photosVM.photoError = nil } }
        )) {
            Button("OK", role: .cancel) { photosVM.photoError = nil }
        } message: {
            Text(photosVM.photoError ?? "")
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: Spacing.md) {
            Spacer()
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 48))
                .foregroundStyle(Color.plurFaint)
            Text("No photos yet")
                .font(.plurH3())
                .foregroundStyle(Color.plurMuted)
            Text("Add photos to start the album")
                .font(.plurCaption())
                .foregroundStyle(Color.plurFaint)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Photo Grid

    private var photoGrid: some View {
        ScrollView {
            if isBatchActive || photosVM.isUploadingPhoto {
                HStack(spacing: Spacing.xs) {
                    ProgressView()
                        .tint(Color.plurViolet)
                    Text("Adding photos…")
                        .font(.plurCaption())
                        .foregroundStyle(Color.plurMuted)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.sm)
            }

            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(photos) { photo in
                    PhotoThumbnail(photo: photo)
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                fullscreenPhoto = photo
                            }
                        }
                        .contextMenu {
                            if photo.userId == partyVM.currentUserId {
                                Button(role: .destructive) {
                                    Task { await photosVM.deletePhoto(photo, in: party.id) }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            if let caption = photo.caption, !caption.isEmpty {
                                Text(caption)
                            }
                        }
                }
            }
            .padding(2)
        }
    }

    // MARK: - Upload Bar

    private var uploadBar: some View {
        PhotosPicker(
            selection: $selectedPickerItems,
            maxSelectionCount: 50,
            matching: .images,
            photoLibrary: .shared()
        ) {
            Label("Add Photos", systemImage: "photo.stack.badge.plus")
                .font(.plurBodyBold())
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.sm)
                .background(Color.plurViolet, in: RoundedRectangle(cornerRadius: Radius.pill))
        }
        .disabled(photosVM.isUploadingPhoto || isCompressing || isBatchActive)
        .opacity((photosVM.isUploadingPhoto || isCompressing || isBatchActive) ? 0.5 : 1)
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
        .background(
            Rectangle()
                .fill(Color.plurSurface)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Color.plurBorder)
                        .frame(height: 1)
                }
        )
    }

    // MARK: - Fullscreen Overlay

    private func fullscreenOverlay(_ photo: Photo) -> some View {
        ZStack {
            Color.black.opacity(0.95).ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            fullscreenPhoto = nil
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(Color.plurGhost.opacity(0.8))
                    }
                    .padding(Spacing.md)
                }

                Spacer()

                AsyncImage(url: URL(string: photo.imageURL)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: Radius.thumbnail))
                    case .failure:
                        placeholder(icon: "exclamationmark.triangle")
                    case .empty:
                        ProgressView().tint(Color.plurViolet)
                    @unknown default:
                        EmptyView()
                    }
                }
                .padding(.horizontal, Spacing.md)

                if let caption = photo.caption, !caption.isEmpty {
                    Text(caption)
                        .font(.plurBody())
                        .foregroundStyle(Color.plurGhost)
                        .multilineTextAlignment(.center)
                        .padding(.top, Spacing.md)
                        .padding(.horizontal, Spacing.lg)
                }

                Spacer()
            }
        }
        .transition(.opacity)
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                fullscreenPhoto = nil
            }
        }
    }

    // MARK: - Helpers

    @MainActor
    private func handlePickedItems(_ items: [PhotosPickerItem]) async {
        pickErrorMessage = nil
        photosVM.photoError = nil
        isBatchActive = true
        selectedPickerItems = []

        var prepareFailures = 0
        for item in items {
            isCompressing = true
            let raw: Data?
            if let picked = try? await item.loadTransferable(type: PickedImageData.self) {
                raw = picked.data
            } else {
                raw = try? await item.loadTransferable(type: Data.self)
            }
            isCompressing = false

            guard let data = raw else {
                prepareFailures += 1
                continue
            }
            guard let compressed = compressImage(data: data, maxBytes: 2_000_000) else {
                prepareFailures += 1
                continue
            }

            _ = await photosVM.uploadPhoto(
                to: party.id,
                userId: partyVM.currentUserId ?? UUID(),
                imageData: compressed,
                caption: nil
            )
        }

        isBatchActive = false
        if prepareFailures == 1 {
            pickErrorMessage = "1 photo couldn't be read or processed."
        } else if prepareFailures > 1 {
            pickErrorMessage = "\(prepareFailures) photos couldn't be read or processed."
        }
    }

    private func compressImage(data: Data, maxBytes: Int) -> Data? {
        guard let uiImage = UIImage(data: data) else { return nil }

        let maxDimension: CGFloat = 1200
        let scale = min(maxDimension / uiImage.size.width, maxDimension / uiImage.size.height, 1.0)
        let targetSize = CGSize(width: uiImage.size.width * scale, height: uiImage.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let resized = renderer.image { _ in
            uiImage.draw(in: CGRect(origin: .zero, size: targetSize))
        }

        var quality: CGFloat = 0.85
        while quality > 0.1 {
            if let jpeg = resized.jpegData(compressionQuality: quality), jpeg.count <= maxBytes {
                return jpeg
            }
            quality -= 0.15
        }
        return resized.jpegData(compressionQuality: 0.1)
    }

    private func placeholder(icon: String) -> some View {
        ZStack {
            Color.plurSurface2
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(Color.plurFaint)
        }
    }
}

// MARK: - Thumbnail

private struct PhotoThumbnail: View {
    let photo: Photo

    var body: some View {
        AsyncImage(url: URL(string: photo.imageURL)) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                    .clipped()
            case .failure:
                fallbackCell(icon: "exclamationmark.triangle")
            case .empty:
                ZStack {
                    Color.plurSurface2
                    ProgressView()
                        .tint(Color.plurViolet)
                }
            @unknown default:
                EmptyView()
            }
        }
        .aspectRatio(1, contentMode: .fill)
    }

    private func fallbackCell(icon: String) -> some View {
        ZStack {
            Color.plurSurface2
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(Color.plurFaint)
        }
    }
}
