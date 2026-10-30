import OSLog
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// Settings → Your Data: export to a JSON file, and import one back (merging).
struct DataTransferSection: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var entries: [PlaceEntry]

    @State private var isImporting = false
    @State private var importResult: ImportResult?

    private enum ImportResult: Identifiable {
        case success(ImportSummary)
        case failure(String)

        var id: String {
            switch self {
            case .success(let summary): "success-\(summary.added)-\(summary.merged)-\(summary.skipped)"
            case .failure(let message): "failure-\(message)"
            }
        }
    }

    var body: some View {
        Section {
            ShareLink(
                item: ExportPackage(file: DataTransfer.exportFile(from: entries)),
                preview: SharePreview("Expedition Data", icon: Image(systemName: "map"))
            ) {
                Label("Export Data", systemImage: "square.and.arrow.up")
            }
            .disabled(entries.isEmpty)

            Button("Import Data…", systemImage: "square.and.arrow.down") {
                isImporting = true
            }
        } header: {
            Text("Your Data")
        } footer: {
            Text("Export saves all your places and memories to a file. Importing adds a file's places to yours. Nothing is deleted or overwritten.")
        }
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.json]) { result in
            importResult = handleImport(result)
        }
        .alert(item: $importResult) { result in
            switch result {
            case .success(let summary):
                Alert(title: Text("Import Complete"), message: Text(message(for: summary)))
            case .failure(let message):
                Alert(title: Text("Couldn't Import"), message: Text(message))
            }
        }
    }

    private func handleImport(_ result: Result<URL, any Error>) -> ImportResult {
        do {
            let url = try result.get()
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            let file = try DataTransfer.decode(try Data(contentsOf: url))
            let summary = try DataTransfer.importFile(file, into: PlaceEntryStore(context: modelContext))
            return .success(summary)
        } catch let error as ImportError {
            return .failure(error.localizedDescription)
        } catch {
            Logger.data.error("Import failed: \(error)")
            return .failure(ImportError.unreadable.localizedDescription)
        }
    }

    private func message(for summary: ImportSummary) -> String {
        var parts = [String(localized: "Imported \(summary.total) places: \(summary.added) new, \(summary.merged) merged with existing.")]
        if summary.skipped > 0 {
            parts.append(String(localized: "\(summary.skipped) records weren't recognized and were skipped."))
        }
        return parts.joined(separator: " ")
    }
}
