import CoreGraphics
import Foundation
import SwiftData
import Testing
@testable import expedition

@MainActor
struct YearReviewTests {
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

    private func review(_ year: Int) throws -> YearReview {
        let timeline = Timeline(
            entries: try container.mainContext.fetch(FetchDescriptor<PlaceEntry>()),
            category: nil,
            place: referenceData.place(for:)
        )
        return YearReview(year: try #require(timeline.years.first { $0.year == year }), locale: Locale(identifier: "en_US"))
    }

    private func day(_ year: Int, _ month: Int, _ day: Int) -> VisitDate {
        VisitDate(year: year, month: month, day: day)
    }

    // MARK: Days on the road

    @Test func overlappingDaysCountOnce() throws {
        try record(.park, "zion", [Visit(start: day(2023, 10, 12), end: day(2023, 10, 15))])
        try record(.park, "bryce-canyon", [Visit(start: day(2023, 10, 15))])
        try record(.country, "JP", [Visit(start: day(2023, 4, 2), end: day(2023, 4, 4))])

        #expect(try review(2023).daysOnTheRoad == 7, "Oct 12–15 and Apr 2–4; Bryce shares the 15th")
    }

    @Test func monthAndYearOnlyVisitsAddNoDays() throws {
        try record(.state, "UT", [Visit(start: VisitDate(year: 2023, month: 10))])
        try record(.state, "AZ", [Visit(start: VisitDate(year: 2023))])

        let review = try review(2023)
        #expect(review.daysOnTheRoad == 0)
        #expect(review.longestTrip == nil)
    }

    /// Trips belong to the year they started, days and all.
    @Test func aNewYearsTripCountsInTheYearItStarted() throws {
        try record(.country, "IS", [Visit(start: day(2016, 12, 30), end: day(2017, 1, 2))])

        #expect(try review(2016).daysOnTheRoad == 4)
    }

    // MARK: Highlights

    @Test func longestTripKnownToTheDay() throws {
        try record(.country, "JP", [Visit(start: day(2024, 4, 2), end: day(2024, 4, 12))])
        try record(.park, "zion", [Visit(start: day(2024, 10, 12), end: day(2024, 10, 15))])
        try record(.state, "UT", [Visit(start: VisitDate(year: 2024, month: 10))])
        try record(.country, "FR", [Visit(start: VisitDate(year: 2024, month: 5), end: VisitDate(year: 2024, month: 7))])

        #expect(try review(2024).longestTrip == YearReview.LongestTrip(names: ["Japan"], days: 11))
    }

    @Test func oneDayTripsArentALongestTrip() throws {
        try record(.park, "zion", [Visit(start: day(2024, 10, 12))])
        #expect(try review(2024).longestTrip == nil)
    }

    @Test func countsByCategory() throws {
        try record(.park, "zion", [Visit(start: day(2023, 10, 12)), Visit(start: VisitDate(year: 2016))])
        try record(.state, "UT", [Visit(start: VisitDate(year: 2023, month: 10))])
        try record(.country, "JP", [Visit(start: VisitDate(year: 2023, month: 4))])

        let review = try review(2023)
        let counts: [Int] = [review.placeCount, review.newPlaceCount, review.countryCount, review.stateCount, review.parkCount]
        #expect(counts == [3, 2, 1, 1, 1])
    }

    @Test func tripLinesOldestFirstWithFirstVisitsStarred() throws {
        try record(.park, "zion", [Visit(start: day(2023, 10, 12)), Visit(start: VisitDate(year: 2016))])
        try record(.state, "UT", [Visit(start: VisitDate(year: 2023, month: 10))])
        try record(.country, "FR", [Visit(start: VisitDate(year: 2023, month: 5), end: VisitDate(year: 2023, month: 6))])
        try record(.state, "AZ", [Visit(start: VisitDate(year: 2023))])

        let lines = try review(2023).tripLines
        #expect(lines.map(\.when) == ["2023", "May–Jun", "Oct"])
        #expect(lines.last?.stops == [
            .init(name: "Utah", isFirstVisit: true),
            .init(name: "Zion", isFirstVisit: false),
        ])
    }

    // MARK: Map

    @Test func aUSOnlyYearUsesTheUSMapWithJustThatYearsParks() throws {
        try record(.park, "zion", [Visit(start: day(2023, 10, 12))])
        try record(.park, "denali", [Visit(start: day(2023, 7, 1))])
        try record(.state, "UT", [Visit(start: VisitDate(year: 2023, month: 10))])

        let review = try review(2023)
        let map = PosterMap.year(review.places, states: referenceData.states, countries: referenceData.countries) { _ in 300 }

        #expect(PosterMap.isUnitedStatesOnly(review.places))
        #expect(map.insets.count == 2)
        #expect(Set(map.dots.map(\.placeID.code)) == ["zion", "denali"])
        #expect(map.areas.filter(\.isVisited).map(\.placeID.code) == ["UT"])
    }

    @Test func anyOtherCountryUsesTheWorldMapWithTheUSLit() throws {
        try record(.state, "UT", [Visit(start: VisitDate(year: 2023, month: 10))])
        try record(.country, "JP", [Visit(start: VisitDate(year: 2023, month: 4))])

        let review = try review(2023)
        let map = PosterMap.year(review.places, states: referenceData.states, countries: referenceData.countries) { _ in 340 }

        #expect(!PosterMap.isUnitedStatesOnly(review.places))
        #expect(map.insets.isEmpty)
        #expect(Set(map.areas.filter(\.isVisited).map(\.placeID.code)) == ["JP", "US"])
    }

    // MARK: Poster

    @Test func postShowsFourTripsAndStoryTen() throws {
        let visits = (1...12).map { Visit(start: day(2023, $0, 1)) }
        for (index, code) in ["zion", "arches", "acadia", "glacier", "denali", "olympic"].enumerated() {
            try record(.park, code, [visits[index * 2], visits[index * 2 + 1]])
        }
        let review = try review(2023)

        #expect(review.tripLines.count == 12)
        #expect(YearPoster(review: review, format: .post, referenceData: referenceData).maxTrips == 4)
        #expect(YearPoster(review: review, format: .story, referenceData: referenceData).maxTrips == 10)
    }

    @Test(arguments: [(PosterFormat.post, 2700), (.story, 3840)])
    func rendersAtFullSize(_ format: PosterFormat, height: Int) throws {
        try record(.park, "zion", [Visit(start: day(2023, 10, 12))])
        let yearPoster = YearPoster(review: try review(2023), format: format, referenceData: referenceData)
        let mapPoster = MapPoster(category: .state, format: format, referenceData: referenceData, visitedCodes: ["UT"])

        for image in [PosterRenderer.image(of: yearPoster), PosterRenderer.image(of: mapPoster)] {
            let image = try #require(image)
            #expect((image.width, image.height) == (2160, height))
        }
    }
}
