import OSLog
import SwiftData
import SwiftUI
import UIKit

/// Full-screen photos for one place: swipe between them, pinch or
/// double-tap to zoom, and delete.
struct PhotoViewer: View {
    let placeID: PlaceID

    @Query private var photos: [PlacePhoto]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var selection: PersistentIdentifier
    @State private var isConfirmingDelete = false

    init(placeID: PlaceID, startingAt photo: PlacePhoto) {
        self.placeID = placeID
        _photos = Query(PhotoLibrary.descriptor(for: placeID))
        _selection = State(initialValue: photo.id)
    }

    /// "Photo 2 of 5, added October 30, 2026", for VoiceOver.
    static func label(for photo: PlacePhoto, at index: Int, of count: Int) -> Text {
        Text("Photo \(index + 1) of \(count), added \(photo.addedAt, format: .dateTime.year().month(.wide).day())")
    }

    private var currentIndex: Int? {
        photos.firstIndex { $0.id == selection }
    }

    var body: some View {
        NavigationStack {
            TabView(selection: $selection) {
                ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                    FullPhoto(photo: photo)
                        .accessibilityElement()
                        .accessibilityLabel(Self.label(for: photo, at: index, of: photos.count))
                        .accessibilityAddTraits(.isImage)
                        .tag(photo.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .background(Color.black)
            .ignoresSafeArea()
            .navigationTitle(currentIndex.map { Text("\($0 + 1) of \(photos.count)") } ?? Text(verbatim: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .bottomBar) {
                    Button("Delete Photo", systemImage: "trash", role: .destructive) {
                        isConfirmingDelete = true
                    }
                }
            }
            .confirmationDialog("Delete this photo?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
                Button("Delete Photo", role: .destructive, action: deleteCurrent)
            } message: {
                Text("It will be deleted from all your devices.")
            }
        }
        .environment(\.colorScheme, .dark)
        .onChange(of: photos.isEmpty) { _, isEmpty in
            // Deleted on another device, or the last one deleted here.
            if isEmpty { dismiss() }
        }
    }

    /// Deletes the shown photo and moves to the next one (or the previous,
    /// at the end).
    private func deleteCurrent() {
        guard let index = currentIndex else { return }
        let photo = photos[index]
        let neighbor = photos.indices.contains(index + 1) ? photos[index + 1] : (index > 0 ? photos[index - 1] : nil)
        do {
            try PhotoLibrary(context: modelContext).delete(photo)
        } catch {
            Logger.data.error("Deleting a photo from \(placeID.code) failed: \(error)")
            return
        }
        if let neighbor {
            selection = neighbor.id
        } else {
            dismiss()
        }
    }
}

/// One page: the thumbnail straight away, then the full image once decoded.
private struct FullPhoto: View {
    let photo: PlacePhoto
    @State private var image: UIImage?

    var body: some View {
        ZoomableImage(image: image)
            .task(id: photo.id) {
                image = await PhotoDecoder.image(from: photo.thumbnailData)
                if let full = await PhotoDecoder.image(from: photo.imageData) {
                    image = full
                }
            }
    }
}

/// Pinch and double-tap zoom, with panning while zoomed. A `UIScrollView`,
/// because that's what makes zooming feel like Photos.
private struct ZoomableImage: UIViewRepresentable {
    let image: UIImage?

    func makeUIView(context: Context) -> ZoomingScrollView {
        ZoomingScrollView()
    }

    func updateUIView(_ view: ZoomingScrollView, context: Context) {
        view.image = image
    }
}

private final class ZoomingScrollView: UIScrollView, UIScrollViewDelegate {
    private let imageView = UIImageView()
    private var fittedForSize: CGSize = .zero

    var image: UIImage? {
        get { imageView.image }
        set {
            guard newValue !== imageView.image else { return }
            let hadImage = imageView.image != nil
            imageView.image = newValue
            // Swapping the thumbnail for the full image (same shape) keeps the zoom.
            if !hadImage || newValue == nil { refit() }
        }
    }

    init() {
        super.init(frame: .zero)
        delegate = self
        minimumZoomScale = 1
        maximumZoomScale = 4
        showsHorizontalScrollIndicator = false
        showsVerticalScrollIndicator = false
        contentInsetAdjustmentBehavior = .never
        decelerationRate = .fast
        imageView.contentMode = .scaleAspectFit
        addSubview(imageView)

        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(toggleZoom(_:)))
        doubleTap.numberOfTapsRequired = 2
        addGestureRecognizer(doubleTap)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if bounds.size != fittedForSize {
            refit()
        }
    }

    /// Sizes the image to fit the screen at zoom 1, centered.
    private func refit() {
        fittedForSize = bounds.size
        zoomScale = 1
        guard let size = imageView.image?.size, size.width > 0, size.height > 0, bounds.width > 0 else {
            imageView.frame = .zero
            contentSize = .zero
            return
        }
        let scale = min(bounds.width / size.width, bounds.height / size.height)
        let fitted = CGSize(width: size.width * scale, height: size.height * scale)
        imageView.frame = CGRect(origin: .zero, size: fitted)
        contentSize = fitted
        center()
    }

    private func center() {
        let horizontal = max(0, (bounds.width - contentSize.width) / 2)
        let vertical = max(0, (bounds.height - contentSize.height) / 2)
        contentInset = UIEdgeInsets(top: vertical, left: horizontal, bottom: vertical, right: horizontal)
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        imageView
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        center()
    }

    @objc private func toggleZoom(_ recognizer: UITapGestureRecognizer) {
        if zoomScale > minimumZoomScale {
            setZoomScale(minimumZoomScale, animated: true)
        } else {
            let point = recognizer.location(in: imageView)
            let scale = 2.5
            let size = CGSize(width: bounds.width / scale, height: bounds.height / scale)
            zoom(to: CGRect(x: point.x - size.width / 2, y: point.y - size.height / 2, width: size.width, height: size.height), animated: true)
        }
    }
}

#if DEBUG
private struct PhotoViewerPreview: View {
    @Query(PhotoLibrary.descriptor(for: PlaceID(category: .park, code: "zion"))) private var photos: [PlacePhoto]

    var body: some View {
        if let first = photos.first {
            PhotoViewer(placeID: PlaceID(category: .park, code: "zion"), startingAt: first)
        }
    }
}

#Preview {
    PhotoViewerPreview()
        .previewEnvironment()
}
#endif
