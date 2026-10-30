import OSLog
import PhotosUI
import SwiftData
import SwiftUI

/// A place's photos in the detail sheet: a row of thumbnails, oldest first,
/// and an Add Photos button.
struct PhotosSection: View {
    let placeID: PlaceID
    /// Opens the viewer. Presented by the detail sheet, not from inside the
    /// Form, where a full-screen cover takes the sheet down with it.
    let onOpen: (PlacePhoto) -> Void

    @Query private var photos: [PlacePhoto]
    @Environment(\.modelContext) private var modelContext
    @State private var selection: [PhotosPickerItem] = []
    /// Photos picked but still being compressed, shown as placeholders.
    @State private var pendingCount = 0
    @State private var failedCount = 0
    @ScaledMetric(relativeTo: .body) private var tileSize = 88.0

    init(placeID: PlaceID, onOpen: @escaping (PlacePhoto) -> Void) {
        self.placeID = placeID
        self.onOpen = onOpen
        _photos = Query(PhotoLibrary.descriptor(for: placeID))
    }

    private var remaining: Int {
        max(0, PhotoLibrary.limit - photos.count - pendingCount)
    }

    var body: some View {
        Section {
            if !photos.isEmpty || pendingCount > 0 {
                thumbnails
            }
            PhotosPicker(
                selection: $selection,
                maxSelectionCount: max(remaining, 1), // 0 would mean unlimited
                selectionBehavior: .ordered,
                matching: .images,
                preferredItemEncoding: .current
            ) {
                Label("Add Photos", systemImage: "plus.circle.fill")
            }
            .disabled(remaining == 0)
            .accessibilityHint(remaining == 0 ? "" : "Up to \(remaining) more")
        } header: {
            Text("Photos")
        } footer: {
            if remaining == 0, pendingCount == 0 {
                Text("Each place can have up to \(PhotoLibrary.limit) photos.")
            }
        }
        .onChange(of: selection) { _, items in
            guard !items.isEmpty else { return }
            selection = []
            add(items)
        }
        .alert(
            "Couldn't Add ^[\(failedCount) Photo](inflect: true)",
            isPresented: Binding(get: { failedCount > 0 }, set: { if !$0 { failedCount = 0 } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("The photo couldn't be read. Try another, or try again later.")
        }
    }

    private var thumbnails: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 8) {
                ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                    Button {
                        onOpen(photo)
                    } label: {
                        PhotoThumbnail(data: photo.thumbnailData)
                            .frame(width: tileSize, height: tileSize)
                            .clipShape(.rect(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Delete Photo", systemImage: "trash", role: .destructive) { delete(photo) }
                    }
                    .accessibilityLabel(PhotoViewer.label(for: photo, at: index, of: photos.count))
                    .accessibilityHint("Opens the photo")
                    .accessibilityAction(named: "Delete") { delete(photo) }
                }
                ForEach(0..<pendingCount, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.inkSoft.opacity(0.15))
                        .frame(width: tileSize, height: tileSize)
                        .overlay { ProgressView() }
                        .accessibilityLabel("Adding photo")
                }
            }
            .padding(.vertical, 4)
        }
        .scrollIndicators(.hidden)
    }

    /// Compresses picked photos one at a time, adding each as it's ready.
    private func add(_ items: [PhotosPickerItem]) {
        pendingCount += items.count
        Task {
            let library = PhotoLibrary(context: modelContext)
            for item in items {
                do {
                    guard let data = try await item.loadTransferable(type: Data.self) else {
                        throw PhotoCompressor.Failure.unreadable
                    }
                    let photo = try await PhotoCompressor.compressed(data)
                    if try library.add([photo], to: placeID) == 0 {
                        Logger.data.notice("Photo limit reached for \(placeID.code)")
                    }
                } catch {
                    Logger.data.error("Adding a photo to \(placeID.code) failed: \(error)")
                    failedCount += 1
                }
                pendingCount -= 1
            }
        }
    }

    private func delete(_ photo: PlacePhoto) {
        do {
            try PhotoLibrary(context: modelContext).delete(photo)
        } catch {
            Logger.data.error("Deleting a photo from \(placeID.code) failed: \(error)")
        }
    }
}

/// A square, cropped thumbnail, decoded off the main thread.
private struct PhotoThumbnail: View {
    let data: Data?
    @State private var image: UIImage?

    var body: some View {
        Color.inkSoft.opacity(0.15)
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                }
            }
            .task(id: data) {
                image = await PhotoDecoder.image(from: data)
            }
    }
}

/// Decodes stored photos away from the main actor.
nonisolated enum PhotoDecoder {
    @concurrent
    static func image(from data: Data?) async -> UIImage? {
        guard let data, let image = UIImage(data: data) else { return nil }
        return await image.byPreparingForDisplay() ?? image
    }
}

#if DEBUG
#Preview("Zion, with photos") {
    Form {
        PhotosSection(placeID: PlaceID(category: .park, code: "zion")) { _ in }
    }
    .previewEnvironment()
}

#Preview("No photos") {
    Form {
        PhotosSection(placeID: PlaceID(category: .park, code: "arches")) { _ in }
    }
    .previewEnvironment()
}
#endif
