import SwiftUI

/// One line in Settings describing iCloud sync.
struct SyncStatusRow: View {
    let status: SyncStatus

    var body: some View {
        // Refresh "5 minutes ago" as time passes.
        TimelineView(.periodic(from: .now, by: 30)) { context in
            Label {
                Text(message(now: context.date))
            } icon: {
                Image(systemName: symbolName)
                    .foregroundStyle(symbolColor)
            }
        }
    }

    private func message(now: Date) -> String {
        switch status {
        case .waiting:
            String(localized: "Waiting to sync with iCloud")
        case .syncing:
            String(localized: "Syncing with iCloud…")
        case .synced(let date):
            now.timeIntervalSince(date) < 60
                ? String(localized: "Synced just now")
                : String(localized: "Last synced \(date.formatted(.relative(presentation: .named)))")
        case .notSignedIn:
            String(localized: "Not signed in to iCloud. Your places are saved on this iPhone only.")
        case .restricted:
            String(localized: "iCloud is restricted on this iPhone. Your places are saved on this iPhone only.")
        case .unavailable:
            String(localized: "iCloud is temporarily unavailable. Your places are safe on this iPhone.")
        case .problem(let problem):
            problem.bannerMessage
        }
    }

    private var symbolName: String {
        switch status {
        case .waiting, .syncing: "arrow.triangle.2.circlepath.icloud"
        case .synced: "checkmark.icloud"
        case .notSignedIn, .restricted, .unavailable: "icloud.slash"
        case .problem(.quotaExceeded): "exclamationmark.icloud"
        case .problem: "icloud.slash"
        }
    }

    private var symbolColor: Color {
        switch status {
        case .synced: .parkVisited
        case .problem: .visited
        default: .secondary
        }
    }
}

#Preview {
    Form {
        Section("iCloud Sync") {
            SyncStatusRow(status: .synced(.now.addingTimeInterval(-300)))
            SyncStatusRow(status: .syncing)
            SyncStatusRow(status: .notSignedIn)
            SyncStatusRow(status: .problem(.quotaExceeded))
        }
    }
}
