import CloudKit
import CoreData
import Foundation
import OSLog

/// Watches CloudKit sync (via the events SwiftData's underlying
/// `NSPersistentCloudKitContainer` posts) and the iCloud account.
@Observable
final class SyncMonitor {
    static let containerIdentifier = "iCloud.com.kubickilabs.expedition"

    private(set) var state = SyncState()
    /// Dismissed banners stay hidden until the next launch, or until a
    /// different problem occurs.
    private(set) var dismissedProblem: SyncProblem?

    var bannerProblem: SyncProblem? {
        guard let problem = state.bannerProblem, problem != dismissedProblem else { return nil }
        return problem
    }

    func dismissBanner() {
        dismissedProblem = state.bannerProblem
    }

    func record(_ event: SyncEvent) {
        state.apply(event)
    }

    /// Runs for the life of the app; call from a `.task`.
    func start() async {
        #if DEBUG
        if let simulated = Self.simulatedState() {
            state = simulated
            return
        }
        #endif
        await withDiscardingTaskGroup { group in
            group.addTask { await self.observeSyncEvents() }
            group.addTask { await self.observeAccount() }
        }
    }

    private func observeSyncEvents() async {
        let events = NotificationCenter.default.notifications(named: NSPersistentCloudKitContainer.eventChangedNotification)
        for await notification in events {
            guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                as? NSPersistentCloudKitContainer.Event else { continue }
            let syncEvent = SyncEvent(event)
            if let problem = syncEvent.problem {
                Logger.sync.error("Sync \(String(describing: syncEvent.kind)) failed (\(problem.rawValue)): \(String(describing: event.error))")
            }
            record(syncEvent)
        }
    }

    private func observeAccount() async {
        await refreshAccount()
        for await _ in NotificationCenter.default.notifications(named: .CKAccountChanged) {
            await refreshAccount()
        }
    }

    private func refreshAccount() async {
        do {
            let status = try await CKContainer(identifier: Self.containerIdentifier).accountStatus()
            state.account = AccountState(status)
        } catch {
            Logger.sync.error("Checking iCloud account failed: \(error)")
            state.account = .unknown
        }
    }

    #if DEBUG
    /// Launch with `-SimulateSyncProblem quota|other|notSignedIn|synced` to
    /// preview sync states without a real iCloud failure.
    private static func simulatedState() -> SyncState? {
        guard let value = UserDefaults.standard.string(forKey: "SimulateSyncProblem") else { return nil }
        var state = SyncState()
        switch value {
        case "notSignedIn":
            state.account = .notSignedIn
        case "synced":
            state.account = .available
            state.apply(SyncEvent(id: UUID(), kind: .export, endDate: .now.addingTimeInterval(-300), succeeded: true, problem: nil))
        default:
            state.account = .available
            let problem: SyncProblem = value == "quota" ? .quotaExceeded : .other
            state.apply(SyncEvent(id: UUID(), kind: .export, endDate: .now, succeeded: false, problem: problem))
        }
        return state
    }
    #endif
}

private extension SyncEvent {
    init(_ event: NSPersistentCloudKitContainer.Event) {
        let kind: Kind = switch event.type {
        case .setup: .setup
        case .import: .import
        default: .export
        }
        self.init(
            id: event.identifier,
            kind: kind,
            endDate: event.endDate,
            succeeded: event.succeeded,
            problem: event.error.map(SyncProblem.init(classifying:))
        )
    }
}

private extension AccountState {
    init(_ status: CKAccountStatus) {
        switch status {
        case .available: self = .available
        case .noAccount: self = .notSignedIn
        case .restricted: self = .restricted
        case .temporarilyUnavailable: self = .temporarilyUnavailable
        default: self = .unknown
        }
    }
}
