import CoreTransferable
import Foundation
import SwiftData
import UniformTypeIdentifiers

/// The JSON file users export and import. Bump `currentVersion` (and keep
/// reading older versions) whenever the shape changes.
///
/// Dates are seconds since 1970 (UTC). Unlike ISO 8601 strings, which keep
/// only milliseconds, they round-trip exactly, so re-importing a file is a no-op.
/// Visit dates are plain year/month/day numbers (see `VisitDate`).
///
/// Version history: 1 had no visits; 2 added `visits`.
nonisolated struct ExportFile: Codable, Sendable {
    static let formatIdentifier = "expedition-export"
    static let currentVersion = 2

    var format = Self.formatIdentifier
    var version = Self.currentVersion
    var exportedAt: Date
    var entries: [ExportedEntry]
}

nonisolated struct ExportedEntry: Codable, Equatable, Sendable {
    var entryID: UUID
    /// `PlaceCategory` raw value; kept as a string so files with categories
    /// this version doesn't know still decode (those entries are skipped).
    var category: String
    var code: String
    var isVisited: Bool
    /// `nil` in version 1 files, which predate visits. (Their `visitDates`
    /// field was always empty, since the app had no way to enter dates.)
    var visits: [Visit]?
    var notes: String
    var favorites: [FavoriteItem]
    var memories: [Memory]
    var createdAt: Date
    var updatedAt: Date
}

nonisolated struct ImportSummary: Equatable, Sendable {
    /// Places that had no entry before the import.
    var added = 0
    /// Places merged into an existing entry (or listed more than once).
    var merged = 0
    /// Records with an unknown category.
    var skipped = 0

    var total: Int { added + merged }
}

nonisolated enum ImportError: LocalizedError, Equatable {
    case notAnExpeditionFile
    case newerVersion(Int)
    case unreadable

    var errorDescription: String? {
        switch self {
        case .notAnExpeditionFile:
            String(localized: "This file isn't an Expedition export.")
        case .newerVersion:
            String(localized: "This file was made by a newer version of Expedition. Update the app to import it.")
        case .unreadable:
            String(localized: "The file couldn't be read. It may be damaged.")
        }
    }
}

/// Export to and import from `ExportFile` JSON.
enum DataTransfer {
    nonisolated static func encode(_ file: ExportFile) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .secondsSince1970
        return try encoder.encode(file)
    }

    nonisolated static func decode(_ data: Data) throws(ImportError) -> ExportFile {
        // Check the header first so a newer file gets a helpful error even if
        // its entries changed shape.
        struct Header: Decodable {
            let format: String?
            let version: Int?
        }
        guard let header = try? JSONDecoder().decode(Header.self, from: data) else {
            throw .unreadable
        }
        guard header.format == ExportFile.formatIdentifier, let version = header.version else {
            throw .notAnExpeditionFile
        }
        guard version <= ExportFile.currentVersion else {
            throw .newerVersion(version)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        do {
            return try decoder.decode(ExportFile.self, from: data)
        } catch {
            throw .unreadable
        }
    }

    /// Snapshot of every entry, sorted so repeated exports are identical.
    static func exportFile(from entries: [PlaceEntry], exportedAt: Date = .now) -> ExportFile {
        let exported = entries
            .map(ExportedEntry.init)
            .sorted { ($0.category, $0.code, $0.entryID.uuidString) < ($1.category, $1.code, $1.entryID.uuidString) }
        return ExportFile(exportedAt: exportedAt, entries: exported)
    }

    /// Adds the file's entries and folds them into existing data with the same
    /// rules as sync duplicates, so nothing is overwritten or lost.
    static func importFile(_ file: ExportFile, into store: PlaceEntryStore) throws -> ImportSummary {
        let context = store.context
        var known = Set(try context.fetch(FetchDescriptor<PlaceEntry>()).compactMap(\.placeID))
        var summary = ImportSummary()

        for record in file.entries {
            guard let category = PlaceCategory(rawValue: record.category), !record.code.isEmpty else {
                summary.skipped += 1
                continue
            }
            let placeID = PlaceID(category: category, code: record.code)
            if known.insert(placeID).inserted {
                summary.added += 1
            } else {
                summary.merged += 1
            }
            context.insert(PlaceEntry(record, placeID: placeID))
        }
        try context.save()
        try store.mergeAllDuplicates()
        return summary
    }
}

private extension ExportedEntry {
    init(_ entry: PlaceEntry) {
        self.init(
            entryID: entry.entryID,
            category: entry.categoryRaw,
            code: entry.placeCode,
            isVisited: entry.isVisited,
            visits: entry.visits.sorted(by: Visit.newestFirst),
            notes: entry.notes,
            favorites: entry.favorites,
            memories: entry.memories,
            createdAt: entry.createdAt,
            updatedAt: entry.updatedAt
        )
    }
}

private extension PlaceEntry {
    convenience init(_ record: ExportedEntry, placeID: PlaceID) {
        self.init(placeID: placeID, createdAt: record.createdAt)
        entryID = record.entryID
        isVisited = record.isVisited
        visits = record.visits ?? []
        notes = record.notes
        favorites = record.favorites
        memories = record.memories
        updatedAt = record.updatedAt
    }
}

/// What the share sheet sends: the export encoded on demand, as a dated
/// `.json` file.
nonisolated struct ExportPackage: Transferable {
    let file: ExportFile

    var fileName: String {
        "Expedition \(file.exportedAt.formatted(Date.ISO8601FormatStyle(timeZone: .current).year().month().day())).json"
    }

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .json) { package in
            try DataTransfer.encode(package.file)
        }
        .suggestedFileName { $0.fileName }
    }
}
