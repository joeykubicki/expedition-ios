import CloudKit
import Foundation

/// What went wrong with iCloud sync, in terms the UI cares about.
nonisolated enum SyncProblem: String, Equatable, Sendable {
    case quotaExceeded
    case notSignedIn
    /// Network down, rate limited, server busy: CloudKit retries on its own.
    case temporary
    case other

    /// Only problems the user should hear about get a banner. Not being
    /// signed in is a valid way to use the app; temporary errors resolve.
    var showsBanner: Bool {
        self == .quotaExceeded || self == .other
    }

    var bannerMessage: String {
        switch self {
        case .quotaExceeded:
            String(localized: "Your iCloud storage is full, so Expedition can't sync. Everything you've saved is safe on this iPhone.")
        default:
            String(localized: "Expedition couldn't sync with iCloud. Your places are safe on this iPhone and will sync when it can.")
        }
    }

    init(classifying error: any Error) {
        let nsError = error as NSError
        if nsError.domain == CKError.errorDomain, let code = CKError.Code(rawValue: nsError.code) {
            self = Self(code: code, partialErrors: nsError.userInfo[CKPartialErrorsByItemIDKey] as? [AnyHashable: any Error])
        } else if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? any Error {
            self = Self(classifying: underlying)
        } else {
            self = .other
        }
    }

    private init(code: CKError.Code, partialErrors: [AnyHashable: any Error]?) {
        switch code {
        case .quotaExceeded:
            self = .quotaExceeded
        case .notAuthenticated:
            self = .notSignedIn
        case .networkUnavailable, .networkFailure, .serviceUnavailable, .requestRateLimited, .zoneBusy:
            self = .temporary
        case .partialFailure:
            // The real causes are per-item; report the most important one.
            let problems = (partialErrors ?? [:]).values.map(Self.init(classifying:))
            if problems.contains(.quotaExceeded) {
                self = .quotaExceeded
            } else if problems.contains(.other) || problems.isEmpty {
                self = .other
            } else if problems.contains(.notSignedIn) {
                self = .notSignedIn
            } else {
                self = .temporary
            }
        default:
            self = .other
        }
    }
}

/// A sync event, independent of `NSPersistentCloudKitContainer.Event` so the
/// state logic can be tested with made-up events.
nonisolated struct SyncEvent: Sendable {
    enum Kind: Sendable {
        case setup, `import`, export
    }

    let id: UUID
    let kind: Kind
    /// `nil` while the event is still running.
    let endDate: Date?
    let succeeded: Bool
    let problem: SyncProblem?
}

nonisolated enum AccountState: Equatable, Sendable {
    case unknown
    case available
    case notSignedIn
    case restricted
    case temporarilyUnavailable
}

/// What Settings shows.
nonisolated enum SyncStatus: Equatable, Sendable {
    case waiting
    case syncing
    case synced(Date)
    case notSignedIn
    case restricted
    case unavailable
    case problem(SyncProblem)
}

/// Folds sync events and account changes into one status.
nonisolated struct SyncState: Equatable, Sendable {
    var account: AccountState = .unknown
    private(set) var lastSuccess: Date?
    private(set) var problem: SyncProblem?
    private var problemKind: SyncEvent.Kind?
    private var runningEvents: Set<UUID> = []

    mutating func apply(_ event: SyncEvent) {
        guard let endDate = event.endDate else {
            runningEvents.insert(event.id)
            return
        }
        runningEvents.remove(event.id)
        if event.succeeded {
            lastSuccess = endDate
            // A success of the same kind (e.g. an export after a quota failure)
            // means that problem is resolved.
            if problemKind == event.kind {
                problem = nil
                problemKind = nil
            }
        } else if let failure = event.problem, failure != .temporary {
            problem = failure
            problemKind = event.kind
        }
    }

    var status: SyncStatus {
        switch account {
        case .notSignedIn: return .notSignedIn
        case .restricted: return .restricted
        case .temporarilyUnavailable: return .unavailable
        case .unknown, .available: break
        }
        if let problem {
            return problem == .notSignedIn ? .notSignedIn : .problem(problem)
        }
        if !runningEvents.isEmpty {
            return .syncing
        }
        if let lastSuccess {
            return .synced(lastSuccess)
        }
        return .waiting
    }

    /// The problem to show in the banner, if any.
    var bannerProblem: SyncProblem? {
        if case .problem(let problem) = status, problem.showsBanner {
            return problem
        }
        return nil
    }
}
