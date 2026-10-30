import Foundation
import MapKit
import SwiftData
import Testing
@testable import expedition

@MainActor
struct YearMapTests {
    let container: ModelContainer
    let store: PlaceEntryStore
    let referenceData = PreviewSupport.referenceData()

    init() throws {
        container = try ModelContainerFactory.make(inMemory: true)
        store = PlaceEntryStore(context: container.mainContext)
    }

    private func record(_ category: PlaceCategory, _ code: String, _ visits: [Visit]) throws {
        let entry = try store.entryOrCreate(for: PlaceID(category: category, code: code))
        entry.isVisited = true
        entry.visits = visits
    }

    private func yearMap(_ year: Int, _ category: PlaceCategory? = nil, showsReturnVisits: Bool = true) throws -> YearMap? {
        let timeline = Timeline(
            entries: try container.mainContext.fetch(FetchDescriptor<PlaceEntry>()),
            category: category,
            showsReturnVisits: showsReturnVisits,
            place: referenceData.place(for:)
        )
        return timeline.years.first { $0.year == year }.map(YearMap.init)
    }

    private func place(_ category: PlaceCategory, _ code: String) throws -> Place {
        try #require(referenceData.place(for: PlaceID(category: category, code: code)))
    }

    private func point(_ latitude: Double, _ longitude: Double) -> MKMapPoint {
        MKMapPoint(CLLocationCoordinate2D(latitude: latitude, longitude: longitude))
    }

    // MARK: Trip numbers

    @Test func numbersTripsOldestFirstSharedWithinATrip() throws {
        try record(.state, "UT", [Visit(start: VisitDate(year: 2023, month: 10))])
        try record(.park, "zion", [
            Visit(start: VisitDate(year: 2023, month: 10, day: 12)),
            Visit(start: VisitDate(year: 2023, month: 3, day: 1)),
        ])
        try record(.country, "JP", [Visit(start: VisitDate(year: 2023, month: 6))])

        let map = try #require(try yearMap(2023))

        #expect(map.trips.map { $0.items.map(\.place.name) } == [["Zion"], ["Japan"], ["Utah", "Zion"]])
        #expect(map.stops.map(\.place.name) == ["Zion", "Japan", "Utah"])
        #expect(map.stops.map(\.tripNumbers) == [[1, 3], [2], [3]])
    }

    @Test func followsTheTimelinesFilterAndReturnSetting() throws {
        try record(.state, "UT", [Visit(start: VisitDate(year: 2023, month: 10))])
        try record(.park, "zion", [Visit(start: VisitDate(year: 2023, month: 10, day: 12)), Visit(start: VisitDate(year: 2016))])

        #expect(try yearMap(2023, .park)?.stops.map(\.place.name) == ["Zion"])
        #expect(try yearMap(2023, showsReturnVisits: false)?.stops.map(\.place.name) == ["Utah"])
    }

    @Test func sample2023IsUtahAndZionOnOneTrip() throws {
        let sample = PreviewSupport.container()
        let timeline = Timeline(
            entries: try sample.mainContext.fetch(FetchDescriptor<PlaceEntry>()),
            category: nil,
            place: referenceData.place(for:)
        )
        let map = YearMap(year: try #require(timeline.years.first { $0.year == 2023 }))
        #expect(map.stops.map(\.place.name) == ["Utah", "Zion"])
        #expect(map.stops.allSatisfy { $0.tripNumbers == [1] })
    }

    // MARK: Framing

    @Test func oneStateFillsTheFrame() throws {
        let rect = try #require(YearMap.mapRect(fitting: [try place(.state, "UT")]))

        #expect(rect.contains(point(40.76, -111.89)), "Salt Lake City")
        #expect(!rect.contains(point(34.05, -118.24)), "Not as far as Los Angeles")
    }

    @Test func aParkIsntShownAtStreetLevel() throws {
        let rect = try #require(YearMap.mapRect(fitting: [try place(.park, "zion")]))
        #expect(rect.width >= YearMap.narrowestSpan / 360 * MKMapSize.world.width)
    }

    /// France's outline includes French Guiana; framing uses the mainland.
    @Test func framesTheMainlandNotOverseasTerritories() throws {
        let rect = try #require(YearMap.mapRect(fitting: [try place(.country, "FR"), try place(.country, "IT")]))

        #expect(rect.contains(point(48.86, 2.35)), "Paris")
        #expect(rect.contains(point(41.90, 12.50)), "Rome")
        #expect(!rect.contains(point(4.9, -52.3)), "Not Cayenne")
    }

    /// Japan and Utah: the short way round is across the Pacific.
    @Test func framesAcrossThe180thMeridian() throws {
        let rect = try #require(YearMap.mapRect(fitting: [try place(.country, "JP"), try place(.state, "UT")]))
        let world = MKMapSize.world.width

        #expect(rect.contains(point(36, 179)), "The mid-Pacific")
        #expect(rect.contains(point(35.68, 139.69)), "Tokyo")
        // `MKMapRect.contains` rejects points past the world's edge, so compare directly.
        let saltLake = point(40.76, -111.89)
        #expect((rect.minX...rect.maxX).contains(saltLake.x + world), "Salt Lake City, past the edge")
        #expect((rect.minY...rect.maxY).contains(saltLake.y))
        #expect(rect.width < world / 2)
    }

    @Test func fijisHalvesSitTogether() throws {
        let rect = try #require(YearMap.mapRect(fitting: [try place(.country, "FJ")]))
        #expect(rect.width < MKMapSize.world.width / 20)
    }

    @Test func spreadOutYearsShowTheWholeWorld() throws {
        let places = [try place(.country, "JP"), try place(.country, "BR"), try place(.country, "FR")]
        #expect(YearMap.mapRect(fitting: places) == nil)
    }
}
