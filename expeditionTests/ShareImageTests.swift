import CoreGraphics
import Foundation
import Testing
@testable import expedition

struct MapProjectionTests {
    @Test func equalEarthReferencePoints() {
        let origin = MapProjection.equalEarth(Coordinate(latitude: 0, longitude: 0))
        let east = MapProjection.equalEarth(Coordinate(latitude: 0, longitude: 180))
        let pole = MapProjection.equalEarth(Coordinate(latitude: 90, longitude: 0))

        #expect(origin == .zero)
        #expect(abs(east.x - 2.70663) < 0.0001)
        #expect(abs(pole.y - 1.31736) < 0.0001)
    }

    @Test func albersCentersOnItsOrigin() {
        let origin = MapProjection.Albers.lower48.project(Coordinate(latitude: 37.5, longitude: -96))
        let northeast = MapProjection.Albers.lower48.project(Coordinate(latitude: 45, longitude: -70))

        #expect(abs(origin.x) < 1e-9 && abs(origin.y) < 1e-9)
        #expect(northeast.x > 0 && northeast.y > 0)
    }

    /// Attu, at the end of the Aleutians, is west of 180°; it should land just
    /// west of mainland Alaska, not on the far side of the world.
    @Test func albersWrapsTheAntimeridian() {
        let attu = MapProjection.Albers.alaska.project(Coordinate(latitude: 52.9, longitude: 172.9))
        let anchorage = MapProjection.Albers.alaska.project(Coordinate(latitude: 61.2, longitude: -149.9))

        #expect(attu.x < anchorage.x)
        #expect(anchorage.x - attu.x < 0.5)
    }
}

@MainActor
struct PosterMapTests {
    let referenceData = PreviewSupport.referenceData()
    let width: CGFloat = 356

    private func map(_ category: PlaceCategory, visited: Set<String> = []) -> PosterMap {
        PosterMap(
            category: category,
            places: referenceData.places(in: category),
            states: referenceData.states,
            visitedCodes: visited,
            width: width
        )
    }

    private func everyPoint(of map: PosterMap) -> [CGPoint] {
        map.areas.flatMap { $0.rings.joined() } + map.dots.map(\.center)
    }

    @Test(arguments: PlaceCategory.allCases)
    func everythingFitsTheMap(_ category: PlaceCategory) {
        let map = map(category)
        let bounds = CGRect(origin: .zero, size: map.size).insetBy(dx: -0.5, dy: -0.5)

        #expect(map.size.width == width)
        #expect(everyPoint(of: map).allSatisfy { bounds.contains($0) })
        #expect(map.insets.allSatisfy { bounds.contains($0) })
    }

    @Test func insetsDontCoverTheLower48() throws {
        let map = map(.park)
        let alaskaAndHawaii: Set<String> = ["AK", "HI"]
        let mainland = map.areas.filter { !alaskaAndHawaii.contains($0.placeID.code) }.flatMap { $0.rings.joined() }
        let alaskaParks = Set(referenceData.parks.filter { $0.stateCodes.first == "AK" }.map(\.id))
        let hawaiiParks = Set(referenceData.parks.filter { $0.stateCodes.first == "HI" }.map(\.id))
        let mainlandDots = map.dots.filter { !alaskaParks.contains($0.placeID) && !hawaiiParks.contains($0.placeID) }

        #expect(map.insets.count == 2)
        for inset in map.insets {
            #expect(!mainland.contains { inset.contains($0) })
            #expect(!mainlandDots.contains { inset.contains($0.center) })
        }
        let alaska = try #require(map.insets.first)
        #expect(map.dots.filter { alaskaParks.contains($0.placeID) }.allSatisfy { alaska.contains($0.center) })
        let alaskaArea = try #require(map.areas.first { $0.placeID.code == "AK" })
        #expect(alaskaArea.rings.joined().allSatisfy { alaska.insetBy(dx: -0.5, dy: -0.5).contains($0) })
    }

    @Test func everyParkAppearsOnce() {
        let map = map(.park, visited: ["zion", "american-samoa"])
        let shown = map.dots.map(\.placeID) + map.outlying.map(\.place.id)

        #expect(shown.count == referenceData.parks.count)
        #expect(Set(shown) == Set(referenceData.parks.map(\.id)))
        #expect(map.outlying.map(\.place.id.code).sorted() == ["american-samoa", "virgin-islands"])
        #expect(map.outlying.first { $0.place.id.code == "american-samoa" }?.isVisited == true)
        #expect(map.dots.filter(\.isVisited).map(\.placeID.code) == ["zion"])
    }

    @Test func parksMapDoesntFillStates() {
        #expect(map(.park, visited: ["UT"]).areas.allSatisfy { !$0.isVisited })
        #expect(map(.state, visited: ["UT"]).areas.filter(\.isVisited).map(\.placeID.code) == ["UT"])
    }

    @Test func antarcticaOnlyWhenVisited() {
        let without = map(.country)
        let with = map(.country, visited: ["AQ"])

        #expect(!without.areas.contains { $0.placeID.code == "AQ" })
        #expect(with.areas.contains { $0.placeID.code == "AQ" })
        #expect(with.size.height > without.size.height)
    }

    @Test func tinyVisitedCountriesGetADot() {
        #expect(map(.country, visited: ["AD"]).dots.map(\.placeID.code) == ["AD"])
        #expect(map(.country, visited: ["FR"]).dots.isEmpty, "France is big enough to see")
        #expect(map(.country).dots.isEmpty)
    }
}

@MainActor
struct MapPosterTests {
    let referenceData = PreviewSupport.referenceData()

    @Test func progressMatchesTheApp() {
        let visited: Set<String> = ["zion", "arches", "not-a-park"]
        let poster = MapPoster(category: .park, referenceData: referenceData, visitedCodes: visited)

        #expect(poster.progress == CategoryProgress(category: .park, places: referenceData.parks, visitedCodes: visited))
        #expect(poster.progress.visited == 2)
    }

    @Test func rendersAt2160By2700() async throws {
        let poster = MapPoster(category: .state, referenceData: referenceData, visitedCodes: ["UT"])
        let image = try #require(PosterRenderer.image(of: poster))

        #expect((image.width, image.height) == (2160, 2700))
        let png = try #require(await PosterRenderer.png(image))
        #expect(png.starts(with: [0x89, 0x50, 0x4E, 0x47]))
    }
}
