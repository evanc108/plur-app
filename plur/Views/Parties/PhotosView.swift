import SwiftUI
import PhotosUI

struct PhotosView: View {
    let party: RaveGroup
    @Bindable var viewModel: PartyViewModel

    @State private var selectedPickerItem: PhotosPickerItem?
    @State private var isCompressing = false
    @State private var fullscreenPhoto: Photo?
    @State private var showCaptionPrompt = false
    @State private var pendingImageData: Data?
    @State private var captionText = ""

    private var photos: [Photo] {
        viewModel.photos[party.id] ?? []
    }

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
    ]

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                if photos.isEmpty && !viewModel.isUploadingPhoto {
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
            await viewModel.loadPhotos(for: party.id)
        }
        .onChange(of: selectedPickerItem) { _, item in
            guard let item else { return }
            Task { await handlePickedItem(item) }
        }
        .alert("Add Caption", isPresented: $showCaptionPrompt) {
            TextField("Caption (optional)", text: $captionText)
            Button("Upload") {
                Task { await commitUpload() }
            }
            Button("Skip") {
                captionText = ""
                Task { await commitUpload() }
            }
            Button("Cancel", role: .cancel) {
                pendingImageData = nil
                captionText = ""
            }
        } message: {
            Text("Add an optional caption to your photo.")
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
            Text("Upload the first photo to start the album")
                .font(.plurCaption())
                .foregroundStyle(Color.plurFaint)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Photo Grid

    private var photoGrid: some View {
        ScrollView {
            if viewModel.isUploadingPhoto {
                HStack(spacing: Spacing.xs) {
                    ProgressView()
                        .tint(Color.plurViolet)
                    Text("Uploading…")
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
                            if photo.userId == viewModel.currentUserId {
                                Button(role: .destructive) {
                                    Task { await viewModel.deletePhoto(photo, in: party.id) }
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
            selection: $selectedPickerItem,
            matching: .images,
            photoLibrary: .shared()
        ) {
            Label("Upload Photo", systemImage: "photo.badge.plus")
                .font(.plurBodyBold())
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.sm)
                .background(Color.plurViolet, in: RoundedRectangle(cornerRadius: Radius.pill))
        }
        .disabled(viewModel.isUploadingPhoto || isCompressing)
        .opacity((viewModel.isUploadingPhoto || isCompressing) ? 0.5 : 1)
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

    private func handlePickedItem(_ item: PhotosPickerItem) async {
        isCompressing = true
        defer {
            isCompressing = false
            selectedPickerItem = nil
        }

        guard let data = try? await item.loadTransferable(type: Data.self) else { return }

        guard let compressed = compressImage(data: data, maxBytes: 2_000_000) else { return }
        pendingImageData = compressed
        showCaptionPrompt = true
    }

    private func commitUpload() async {
        guard let data = pendingImageData else { return }
        let caption = captionText.trimmingCharacters(in: .whitespacesAndNewlines)
        pendingImageData = nil
        captionText = ""
        _ = await viewModel.uploadPhoto(to: party.id, imageData: data, caption: caption.isEmpty ? nil : caption)
    }

    private func compressImage(data: Data, maxBytes: Int) -> Data? {
        guard let uiImage = UIImage(data: data) else { return nil }
        var quality: CGFloat = 0.85
        while quality > 0.1 {
            if let jpeg = uiImage.jpegData(compressionQuality: quality), jpeg.count <= maxBytes {
                return jpeg
            }
            quality -= 0.15
        }
        let maxDimension: CGFloat = 1200
        let scale = min(maxDimension / uiImage.size.width, maxDimension / uiImage.size.height, 1.0)
        let newSize = CGSize(width: uiImage.size.width * scale, height: uiImage.size.height * scale)
        UIGraphicsBeginImageContextWithOptions(newSize, true, 1.0)
        uiImage.draw(in: CGRect(origin: .zero, size: newSize))
        let resized = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return resized?.jpegData(compressionQuality: 0.7)
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
