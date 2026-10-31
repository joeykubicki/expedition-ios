import Foundation
import OSLog
import StoreKit
import SwiftData
import UIKit

/// Decides when to ask for an App Store rating: once the user has visited 10
/// places, or added info (visits, notes, favorites, memories, or photos) to 2
/// visited places. Asks once per device. iOS still decides whether the prompt
/// shows: always in debug builds, never in TestFlight, and at most three
/// times a year on the App Store.
struct ReviewPrompt {
    static let visitedThreshold = 10
    static let placesWithInfoThreshold = 2

    /// How far the user has got toward each threshold.
    struct Counts: Equatable {
        var visited = 0
        var placesWithInfo = 0

        var isDue: Bool {
            visited >= ReviewPrompt.visitedThreshold || placesWithInfo >= ReviewPrompt.placesWithInfoThreshold
        }

        func hasGrown(since earlier: Counts) -> Bool {
            visited > earlier.visited || placesWithInfo > earlier.placesWithInfo
        }
    }

    let context: ModelContext
    var defaults: UserDefaults = .standard

    private static let hasAskedKey = "reviewPrompt.hasAsked"

    var hasAsked: Bool {
        defaults.bool(forKey: Self.hasAskedKey)
    }

    func markAsked() {
        defaults.set(true, forKey: Self.hasAskedKey)
    }

    /// Counted from saved data, so places synced from other devices or
    /// imported count too. `nil` if reading fails.
    func counts() -> Counts? {
        do {
            let visited = try context.fetch(FetchDescriptor<PlaceEntry>(predicate: #Predicate { $0.isVisited }))
            // Keyed by place, so duplicate entries from sync count once.
            let visitedKeys = Set(visited.map { Self.key($0.categoryRaw, $0.placeCode) })
            var withInfo = Set(visited.filter(Self.hasInfo).map { Self.key($0.categoryRaw, $0.placeCode) })

            var photos = FetchDescriptor<PlacePhoto>()
            photos.propertiesToFetch = [\.categoryRaw, \.placeCode]
            for photo in try context.fetch(photos) {
                let key = Self.key(photo.categoryRaw, photo.placeCode)
                if visitedKeys.contains(key) { withInfo.insert(key) }
            }
            return Counts(visited: visitedKeys.count, placesWithInfo: withInfo.count)
        } catch {
            Logger.data.error("Counting places for the review prompt failed: \(error)")
            return nil
        }
    }

    /// Whether to ask now: never asked, a threshold is met, and (given the
    /// counts from before the user's change) the change moved the counts.
    func shouldAsk(since earlier: Counts? = nil) -> Bool {
        guard !hasAsked, let counts = counts(), counts.isDue else { return false }
        return earlier.map(counts.hasGrown) ?? true
    }

    /// Asks for a rating if it's time, after a moment so the prompt doesn't
    /// land on a sheet closing or a checkmark animating.
    func requestIfDue(since earlier: Counts? = nil) {
        guard shouldAsk(since: earlier) else { return }
        markAsked()
        Task {
            try? await Task.sleep(for: .seconds(1))
            // Found at request time rather than taken from a view, since the
            // view that triggered this may be gone by now.
            let scene = UIApplication.shared.connectedScenes
                .first { $0.activationState == .foregroundActive } as? UIWindowScene
            if let scene {
                AppStore.requestReview(in: scene)
            }
        }
    }

    private static func key(_ categoryRaw: String, _ placeCode: String) -> String {
        "\(categoryRaw)/\(placeCode)"
    }

    private static func hasInfo(_ entry: PlaceEntry) -> Bool {
        !entry.visits.isEmpty
            || !entry.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !entry.favorites.isEmpty
            || !entry.memories.isEmpty
    }
}
