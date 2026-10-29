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
            let data = try await Self.loadAll(from: bundle)
            parks = data.parks
            states = data.states
            countries = data.countries
            placesByID = Dictionary(
                (data.parks + data.states + data.countries).map { ($0.id, $0) },
                uniquingKeysWith: { first, _ in first }
            )
            isLoaded = true
        } catch {
            loadError = error
        }
    }

    @concurrent
    private nonisolated static func loadAll(
        from bundle: Bundle
    ) async throws -> (parks: [Place], states: [Place], countries: [Place]) {
        (
            try ReferenceDataLoader.loadParks(from: bundle),
            try ReferenceDataLoader.loadStates(from: bundle),
            try ReferenceDataLoader.loadCountries(from: bundle)
        )
    }
}
