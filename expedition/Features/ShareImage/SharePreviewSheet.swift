import CoreTransferable
import OSLog
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// The category map poster's share sheet, opened from each map tab.
struct SharePreviewSheet: View {
    let category: PlaceCategory

    @Environment(ReferenceDataStore.self) private var referenceData
    @Environment(\.modelContext) private var modelContext
    @State private var visitedCodes: Set<String>?

    var body: some View {
        if let visitedCodes {
            let progress = CategoryProgress(category: category, places: referenceData.places(in: category), visitedCodes: visitedCodes)
            PosterShareSheet(
                fileName: String(localized: "Expedition – \(String(localized: category.title))"),
                accessibilityLabel: String(localized: "Map poster: \(progress.visited) of \(progress.total) \(category.pluralNoun) visited")
            ) { format in
                MapPoster(category: category, format: format, referenceData: referenceData, visitedCodes: visitedCodes)
            }
        } else {
            ProgressView()
                .task {
                    do {
                        visitedCodes = try PlaceEntryStore(context: modelContext).visitedCodes(in: category)
                    } catch {
                        Logger.data.error("Reading visited places for the share image failed: \(error)")
                        visitedCodes = []
                    }
                }
        }
    }
}

/// Previews a poster in the chosen format (remembered across posters) and
/// shares it as a PNG.
struct PosterShareSheet<Poster: View>: View {
    let fileName: String
    let accessibilityLabel: String
    @ViewBuilder let poster: (PosterFormat) -> Poster

    @Environment(\.dismiss) private var dismiss
    @AppStorage("posterFormat") private var format = PosterFormat.post
    @State private var rendered: [PosterFormat: RenderedPoster] = [:]
    @State private var failed: Set<PosterFormat> = []

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Picker("Format", selection: $format) {
                    ForEach(PosterFormat.allCases) { format in
                        Text(format.title).tag(format)
                    }
                }
                .pickerStyle(.segmented)

                preview
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if let current = rendered[format] {
                    ShareLink(
                        item: current,
                        preview: SharePreview(current.title, image: Image(decorative: current.image, scale: 1))
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
            .navigationTitle("Share")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task(id: format) { await render(format) }
        }
    }

    @ViewBuilder
    private var preview: some View {
        if let current = rendered[format] {
            Image(decorative: current.image, scale: PosterFormat.scale)
                .resizable()
                .scaledToFit()
                .clipShape(.rect(cornerRadius: 6))
                .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
                .accessibilityElement()
                .accessibilityLabel(accessibilityLabel)
                .accessibilityAddTraits(.isImage)
        } else if failed.contains(format) {
            ContentUnavailableView(
                "Couldn't Make the Image",
                systemImage: "exclamationmark.triangle",
                description: Text("Try again in a moment.")
            )
        } else {
            ProgressView("Drawing your map…")
        }
    }

    private func render(_ format: PosterFormat) async {
        guard rendered[format] == nil else { return }
        guard let image = PosterRenderer.image(of: poster(format)), let png = await PosterRenderer.png(image) else {
            failed.insert(format)
            return
        }
        let suffix = format == .story ? String(localized: " (Story)") : ""
        rendered[format] = RenderedPoster(image: image, png: png, title: fileName + suffix)
    }
}

/// The finished poster, shared as a PNG named after it.
struct RenderedPoster: Transferable {
    let image: CGImage
    let png: Data
    let title: String

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
