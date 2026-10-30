import CoreTransferable
import OSLog
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// Shows the rendered map poster for a category, with a Share button.
struct SharePreviewSheet: View {
    let category: PlaceCategory

    @Environment(ReferenceDataStore.self) private var referenceData
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var rendered: RenderedPoster?
    @State private var didFail = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                preview
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                if let rendered {
                    ShareLink(
                        item: rendered,
                        preview: SharePreview(rendered.title, image: Image(decorative: rendered.image, scale: 1))
                    ) {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .background(Color.paper)
            .navigationTitle("Share Map")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task { await render() }
        }
    }

    @ViewBuilder
    private var preview: some View {
        if let rendered {
            Image(decorative: rendered.image, scale: MapPoster.scale)
                .resizable()
                .scaledToFit()
                .clipShape(.rect(cornerRadius: 6))
                .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
                .accessibilityElement()
                .accessibilityLabel(rendered.accessibilityLabel)
                .accessibilityAddTraits(.isImage)
        } else if didFail {
            ContentUnavailableView(
                "Couldn't Make the Image",
                systemImage: "exclamationmark.triangle",
                description: Text("Try again in a moment.")
            )
        } else {
            ProgressView("Drawing your map…")
        }
    }

    private func render() async {
        guard rendered == nil else { return }
        do {
            let visitedCodes = try PlaceEntryStore(context: modelContext).visitedCodes(in: category)
            let poster = MapPoster(category: category, referenceData: referenceData, visitedCodes: visitedCodes)
            guard let image = PosterRenderer.image(of: poster), let png = await PosterRenderer.png(image) else {
                didFail = true
                return
            }
            rendered = RenderedPoster(
                image: image,
                png: png,
                title: String(localized: "Expedition – \(String(localized: category.title))"),
                accessibilityLabel: String(localized: "Map poster: \(poster.progress.visited) of \(poster.progress.total) \(category.pluralNoun) visited")
            )
        } catch {
            Logger.data.error("Making the share image failed: \(error)")
            didFail = true
        }
    }
}

/// The finished poster, shared as a PNG named after it.
struct RenderedPoster: Transferable {
    let image: CGImage
    let png: Data
    let title: String
    let accessibilityLabel: String

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { $0.png }
            .suggestedFileName { "\($0.title).png" }
    }
}

#if DEBUG
#Preview {
    Color.clear.sheet(isPresented: .constant(true)) {
        SharePreviewSheet(category: .park)
    }
    .previewEnvironment()
}
#endif
