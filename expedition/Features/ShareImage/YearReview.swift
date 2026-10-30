import Foundation

/// A year's highlights for the year-in-review poster, from what the Timeline
/// shows for that year.
struct YearReview: Identifiable, Equatable {
    /// One line of the poster's trip list: "Oct · Utah and ★ Zion".
    struct TripLine: Identifiable, Equatable {
        struct Stop: Equatable {
            let name: String
            /// Visited for the first time on this trip.
            let isFirstVisit: Bool
        }

        let id: UUID
        /// "Oct", "May–Jun", or the year for year-only visits.
        let when: String
        let stops: [Stop]
    }

    struct LongestTrip: Equatable {
        let names: [String]
        let days: Int
    }

    let year: Int
    let placeCount: Int
    let newPlaceCount: Int
    let countryCount: Int
    let stateCount: Int
    let parkCount: Int
    /// Distinct days covered by visits with exact dates; month- and year-only
    /// visits don't count, so this can be low. 0 when there are none.
    let daysOnTheRoad: Int
    /// The longest trip known to the day, if it lasted at least two days.
    let longestTrip: LongestTrip?
    /// Oldest first.
    let tripLines: [TripLine]
    /// Each place once, for the map.
    let places: [Place]

    var id: Int { year }

    init(year: Timeline.Year, locale: Locale = .autoupdatingCurrent) {
        self.year = year.year
        let items = year.items
        placeCount = year.placeCount
        newPlaceCount = year.newPlaceCount
        countryCount = year.countryCount
        func count(_ category: PlaceCategory) -> Int {
            Set(items.filter { $0.place.category == category }.map(\.place.id)).count
        }
        stateCount = count(.state)
        parkCount = count(.park)

        var days: Set<Int> = []
        for item in items {
            if let range = Self.dayNumbers(of: item.visit) { days.formUnion(range) }
        }
        daysOnTheRoad = days.count

        let trips = Array(year.trips.reversed())
        var seen: Set<PlaceID> = []
        places = items.map(\.place).filter { seen.insert($0.id).inserted }

        let longest = trips
            .compactMap { trip in Self.dayNumbers(of: trip.span).map { (trip: trip, days: $0.count) } }
            .max { $0.days < $1.days }
        longestTrip = longest.flatMap { longest in
            longest.days >= 2 ? LongestTrip(names: Self.stops(of: longest.trip).map(\.name), days: longest.days) : nil
        }

        tripLines = trips.map { trip in
            TripLine(id: trip.id, when: Self.when(trip.span, locale: locale), stops: Self.stops(of: trip))
        }
    }

    /// Days since 1970 covered by a visit known to the day; `nil` otherwise.
    static func dayNumbers(of visit: Visit) -> ClosedRange<Int>? {
        guard visit.start.precision == .day else { return nil }
        func number(_ date: VisitDate) -> Int { Int((date.date.timeIntervalSince1970 / 86_400).rounded(.down)) }
        return number(visit.start)...number(visit.end ?? visit.start)
    }

    /// Each place once, in trip order; a first visit if any of its visits on
    /// the trip was.
    private static func stops(of trip: Timeline.Trip) -> [TripLine.Stop] {
        var order: [PlaceID] = []
        var stops: [PlaceID: TripLine.Stop] = [:]
        for item in trip.items {
            if stops[item.place.id] == nil { order.append(item.place.id) }
            let isFirst = (stops[item.place.id]?.isFirstVisit ?? false) || !item.isReturn
            stops[item.place.id] = TripLine.Stop(name: item.place.name, isFirstVisit: isFirst)
        }
        return order.compactMap { stops[$0] }
    }

    /// "Oct", "May–Jun", "Dec–Jan", or "2019" when only the year is known.
    private static func when(_ span: Visit, locale: Locale) -> String {
        guard span.start.month != nil else { return String(span.start.year) }
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = VisitDate.calendar
        formatter.timeZone = VisitDate.calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate("MMM")
        let start = formatter.string(from: span.start.date)
        guard let end = span.end, end.truncated(to: .month) != span.start.truncated(to: .month) else { return start }
        return "\(start)–\(formatter.string(from: end.date))"
    }
}
