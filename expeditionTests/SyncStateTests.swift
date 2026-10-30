import CloudKit
import Foundation
import Testing
@testable import expedition

struct SyncProblemTests {
    private func ckError(_ code: CKError.Code, userInfo: [String: Any] = [:]) -> NSError {
        NSError(domain: CKError.errorDomain, code: code.rawValue, userInfo: userInfo)
    }

    @Test func quotaExceeded() {
        #expect(SyncProblem(classifying: ckError(.quotaExceeded)) == .quotaExceeded)
    }

    @Test func notAuthenticated() {
        #expect(SyncProblem(classifying: ckError(.notAuthenticated)) == .notSignedIn)
    }

    @Test(arguments: [CKError.Code.networkUnavailable, .networkFailure, .serviceUnavailable, .requestRateLimited, .zoneBusy])
    func transientErrorsAreTemporary(_ code: CKError.Code) {
        #expect(SyncProblem(classifying: ckError(code)) == .temporary)
    }

    @Test func otherCloudKitErrors() {
        #expect(SyncProblem(classifying: ckError(.internalError)) == .other)
        #expect(SyncProblem(classifying: ckError(.serverRejectedRequest)) == .other)
    }

    @Test func nonCloudKitErrorsAreOther() {
        #expect(SyncProblem(classifying: CocoaError(.fileWriteUnknown)) == .other)
    }

    @Test func partialFailureReportsMostImportantCause() {
        let quota = ckError(.partialFailure, userInfo: [CKPartialErrorsByItemIDKey: [
            "a": ckError(.networkFailure),
            "b": ckError(.quotaExceeded),
        ]])
        let transient = ckError(.partialFailure, userInfo: [CKPartialErrorsByItemIDKey: [
            "a": ckError(.networkFailure),
            "b": ckError(.zoneBusy),
        ]])

        #expect(SyncProblem(classifying: quota) == .quotaExceeded)
        #expect(SyncProblem(classifying: transient) == .temporary)
        #expect(SyncProblem(classifying: ckError(.partialFailure)) == .other)
    }

    @Test func underlyingCloudKitErrorIsFound() {
        let wrapped = NSError(domain: "NSCocoaErrorDomain", code: 134_400, userInfo: [
            NSUnderlyingErrorKey: ckError(.quotaExceeded),
        ])
        #expect(SyncProblem(classifying: wrapped) == .quotaExceeded)
    }

    @Test func onlyQuotaAndOtherShowBanners() {
        #expect(SyncProblem.quotaExceeded.showsBanner)
        #expect(SyncProblem.other.showsBanner)
        #expect(!SyncProblem.notSignedIn.showsBanner)
        #expect(!SyncProblem.temporary.showsBanner)
    }

    @Test func messagesReassureDataIsSafe() {
        for problem in [SyncProblem.quotaExceeded, .other] {
            #expect(problem.bannerMessage.contains("safe on this iPhone"))
        }
    }
}

struct SyncStateTests {
    let date = Date(timeIntervalSince1970: 1_000)

    private func started(_ kind: SyncEvent.Kind = .export, id: UUID) -> SyncEvent {
        SyncEvent(id: id, kind: kind, endDate: nil, succeeded: false, problem: nil)
    }

    private func finished(_ kind: SyncEvent.Kind = .export, id: UUID = UUID(), problem: SyncProblem? = nil, at date: Date? = nil) -> SyncEvent {
        SyncEvent(id: id, kind: kind, endDate: date ?? self.date, succeeded: problem == nil, problem: problem)
    }

    @Test func startsWaiting() {
        #expect(SyncState().status == .waiting)
    }

    @Test func runningThenSynced() {
        var state = SyncState()
        let id = UUID()
        state.apply(started(id: id))
        #expect(state.status == .syncing)

        state.apply(finished(id: id))
        #expect(state.status == .synced(date))
    }

    @Test func quotaFailureShowsBannerUntilExportSucceeds() {
        var state = SyncState()
        state.apply(finished(.export, problem: .quotaExceeded))
        #expect(state.bannerProblem == .quotaExceeded)

        // An import succeeding doesn't fix an export quota problem.
        state.apply(finished(.import))
        #expect(state.bannerProblem == .quotaExceeded)

        state.apply(finished(.export, at: date.addingTimeInterval(60)))
        #expect(state.bannerProblem == nil)
        #expect(state.status == .synced(date.addingTimeInterval(60)))
    }

    @Test func temporaryFailuresAreIgnored() {
        var state = SyncState()
        state.apply(finished(problem: .temporary))
        #expect(state.bannerProblem == nil)
        #expect(state.status == .waiting)
    }

    @Test func signedOutAccountWinsWithoutBanner() {
        var state = SyncState()
        state.apply(finished(problem: .other))
        state.account = .notSignedIn

        #expect(state.status == .notSignedIn)
        #expect(state.bannerProblem == nil)
    }

    @Test func notAuthenticatedErrorShowsAsNotSignedIn() {
        var state = SyncState()
        state.apply(finished(problem: .notSignedIn))

        #expect(state.status == .notSignedIn)
        #expect(state.bannerProblem == nil)
    }

    @Test func restrictedAndUnavailableAccounts() {
        var state = SyncState()
        state.account = .restricted
        #expect(state.status == .restricted)
        state.account = .temporarilyUnavailable
        #expect(state.status == .unavailable)
    }
}

@MainActor
struct SyncMonitorTests {
    private func failure(_ problem: SyncProblem) -> SyncEvent {
        SyncEvent(id: UUID(), kind: .export, endDate: .now, succeeded: false, problem: problem)
    }

    @Test func dismissedProblemStaysHiddenEvenIfItRecurs() {
        let monitor = SyncMonitor()
        monitor.record(failure(.quotaExceeded))
        #expect(monitor.bannerProblem == .quotaExceeded)

        monitor.dismissBanner()
        #expect(monitor.bannerProblem == nil)

        monitor.record(failure(.quotaExceeded))
        #expect(monitor.bannerProblem == nil)
    }

    @Test func differentProblemShowsAgainAfterDismissal() {
        let monitor = SyncMonitor()
        monitor.record(failure(.quotaExceeded))
        monitor.dismissBanner()

        monitor.record(failure(.other))
        #expect(monitor.bannerProblem == .other)
    }

    @Test func dismissingWithNothingShowingDoesNothing() {
        let monitor = SyncMonitor()
        monitor.dismissBanner()
        monitor.record(failure(.other))
        #expect(monitor.bannerProblem == .other)
    }
}
