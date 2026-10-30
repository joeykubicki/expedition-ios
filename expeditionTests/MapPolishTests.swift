import Foundation
import MapKit
import Testing
@testable import expedition

struct AntimeridianSeamsTests {
    private func c(_ latitude: Double, _ longitude: Double) -> Coordinate {
        Coordinate(latitude: latitude, longitude: longitude)
    }

    @Test func ringsAwayFromTheAntimeridianAreStrokedWhole() {
        #expect(AntimeridianSeams.outlineRuns(of: [c(0, 0), c(0, 1), c(1, 1), c(1, 0), c(0, 0)]) == nil)
    }

    @Test func aSingleVertexOnTheAntimeridianIsNotASeam() {
        #expect(AntimeridianSeams.outlineRuns(of: [c(0, 179), c(1, 180), c(2, 179), c(0, 179)]) == nil)
    }

    @Test func dropsTheEdgeAlongTheCut() {
        // A square touching the cut from the west (at 180°) and from the east (at -180°).
        let ring = [c(60, 178), c(60, 180), c(70, 180), c(70, 178), c(60, 178)]
        #expect(AntimeridianSeams.outlineRuns(of: ring) == [[c(70, 180), c(70, 178), c(60, 178), c(60, 180)]])

        let west = [c(60, -180), c(60, -178), c(70, -178), c(70, -180), c(60, -180)]
        #expect(AntimeridianSeams.outlineRuns(of: west) == [[c(60, -180), c(60, -178), c(70, -178), c(70, -180)]])
    }

    @Test func splitsAroundSeveralCuts() {
        // Two stretches along the cut, separated by a bay that dips west of it.
        let ring = [c(60, 180), c(62, 180), c(63, 179), c(64, 180), c(66, 180), c(66, 178), c(60, 178), c(60, 180)]
        #expect(AntimeridianSeams.outlineRuns(of: ring) == [
            [c(62, 180), c(63, 179), c(64, 180)],
            [c(66, 180), c(66, 178), c(60, 178), c(60, 180)],
        ])
    }

    @MainActor @Test func chukotkaHasNoBorderDownTheCut() throws {
        let countries = try ReferenceDataLoader.loadCountries(locale: Locale(identifier: "en_US"))
        let russia = try #require(countries.first { $0.id.code == "RU" })
        let shapes = MapShape.shapes(for: [russia])
        let seamless = shapes.filter { $0.seamlessOutline != nil }

        #expect(!seamless.isEmpty)
        #expect(seamless.count < shapes.count, "Only the pieces touching 180° need special outlines")
    }
}

struct ParkClustererTests {
    let parks = try! ReferenceDataLoader.loadParks()

    private func park(_ code: String) -> Place {
        parks.first { $0.id.code == code }!
    }

    let spacing = CGSize(width: 44, height: 30)

    /// Screen points per map point when `degrees` of longitude fill 400 points.
    private func scale(showing degrees: Double) -> Double {
        400 / (MKMapSize.world.width * degrees / 360)
    }

    @Test func noScaleMeansNoClusters() {
        let clusters = ParkClusterer.clusters(for: parks, pointsPerMapPoint: nil, spacing: spacing)
        #expect(clusters.count == parks.count)
        #expect(clusters.allSatisfy { $0.isSingle })
    }

    @Test func zoomedOutGroupsNeighbors() throws {
        let clusters = ParkClusterer.clusters(for: parks, pointsPerMapPoint: scale(showing: 62), spacing: spacing)
        let arches = try #require(clusters.first { $0.parks.contains(park("arches")) })

        #expect(arches.parks.contains(park("canyonlands")))
        #expect(clusters.count < parks.count)
        #expect(clusters.flatMap(\.parks).count == parks.count, "Every park appears exactly once")
        #expect(Set(clusters.flatMap(\.parks)).count == parks.count)
    }

    @Test func noTwoMarkersOverlap() {
        let pointsPerMapPoint = scale(showing: 62)
        let clusters = ParkClusterer.clusters(for: parks, pointsPerMapPoint: pointsPerMapPoint, spacing: spacing)
        let centers = clusters.map { MKMapPoint($0.coordinate.clLocationCoordinate) }

        for i in centers.indices {
            for j in centers.indices where j > i {
                let dx = abs(centers[i].x - centers[j].x) * pointsPerMapPoint
                let dy = abs(centers[i].y - centers[j].y) * pointsPerMapPoint
                #expect(dx >= spacing.width - 0.001 || dy >= spacing.height - 0.001, "\(clusters[i].id) and \(clusters[j].id)")
            }
        }
    }

    @Test func zoomedInSeparatesEveryone() {
        let clusters = ParkClusterer.clusters(for: parks, pointsPerMapPoint: scale(showing: 1.5), spacing: spacing)
        #expect(clusters.allSatisfy { $0.isSingle })
    }

    @Test func zoomRegionSeparatesTheClosestPair() {
        let pair = [park("sequoia"), park("kings-canyon")]
        let region = ParkCluster(parks: pair).zoomRegion
        let clusters = ParkClusterer.clusters(
            for: pair, pointsPerMapPoint: scale(showing: region.span.longitudeDelta), spacing: spacing
        )
        #expect(clusters.count == 2)
    }

    @Test func clusterSitsBetweenItsParks() {
        let cluster = ParkCluster(parks: [park("arches"), park("canyonlands")])
        let latitudes = cluster.parks.map(\.labelCoordinate.latitude)
        #expect((latitudes.min()!...latitudes.max()!).contains(cluster.coordinate.latitude))
    }
}
