import Foundation
import Observation

/// Holds the bundled reference data for the UI. Load once at launch.
@Observable
final class ReferenceDataStore {
    private(set) var parks: [Place] = []
    private(set) var states: [Place] = []
    private(set) var countries: [Place] = []
    private(set) var isLoaded = false
    private(set) var loadError: (any Error)?

    private var placesByID: [PlaceID: Place] = [:]

    private typealias LoadedPlaces = (parks: [Place], states: [Place], countries: [Place])

    func places(in category: PlaceCategory) -> [Place] {
        switch category {
        case .park: parks
        case .state: states
        case .country: countries
        }
    }

    func place(for id: PlaceID) -> Place? {
        placesByID[id]
    }

    func load(from bundle: Bundle = .main) async {
        guard !isLoaded else { return }
        do {
            apply(try await Self.loadAll(from: bundle))
        } catch {
            loadError = error
        }
    }

    /// Loads on the calling thread. For Previews and tests only; the app uses
    /// `load()` so launch isn't blocked.
    func loadSynchronously(from bundle: Bundle = .main) throws {
        guard !isLoaded else { return }
        apply(try Self.loadAllSynchronously(from: bundle))
    }

    private func apply(_ data: LoadedPlaces) {
        parks = data.parks
        states = data.states
        countries = data.countries
        placesByID = Dictionary(
            (data.parks + data.states + data.countries).map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        isLoaded = true
    }

    @concurrent
    private nonisolated static func loadAll(from bundle: Bundle) async throws -> LoadedPlaces {
        try loadAllSynchronously(from: bundle)
    }

    private nonisolated static func loadAllSynchronously(from bundle: Bundle) throws -> LoadedPlaces {
        (
            try ReferenceDataLoader.loadParks(from: bundle),
            try ReferenceDataLoader.loadStates(from: bundle),
            try ReferenceDataLoader.loadCountries(from: bundle)
        )
    }
}
