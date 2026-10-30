import Foundation

/// One trip to a place: a start date and, for longer trips, an end date.
nonisolated struct Visit: Codable, Hashable, Identifiable, Sendable {
    var id: UUID = UUID()
    var start: VisitDate
    /// Same precision as `start` and after it; `nil` for a single day,
    /// month, or year.
    var end: VisitDate?

    init(id: UUID = UUID(), start: VisitDate, end: VisitDate? = nil) {
        self.id = id
        self.start = start
        self.end = end
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        start = try container.decode(VisitDate.self, forKey: .start)
        end = try container.decodeIfPresent(VisitDate.self, forKey: .end)
        if let end, end.precision != start.precision || end <= start {
            throw DecodingError.dataCorruptedError(
                forKey: .end, in: container,
                debugDescription: "A visit's end must match its start's precision and come after it"
            )
        }
    }

    /// Newest first: later start, then later end, then a stable tiebreak.
    static func newestFirst(_ a: Visit, _ b: Visit) -> Bool {
        if a.start != b.start { return a.start > b.start }
        let aEnd = a.end ?? a.start, bEnd = b.end ?? b.start
        if aEnd != bEnd { return aEnd > bEnd }
        return a.id.uuidString < b.id.uuidString
    }
}

/// A calendar date known to the day, the month, or only the year. Stored as
/// numbers rather than a `Date` so it names the same day in every time zone:
/// a visit entered in California never shows up a day early in Tokyo.
nonisolated struct VisitDate: Codable, Hashable, Comparable, Sendable {
    enum Precision: String, CaseIterable, Codable, Sendable {
        case day, month, year
    }

    let year: Int
    /// 1–12; `nil` when only the year is known.
    let month: Int?
    /// 1–31; only set together with `month`.
    let day: Int?

    init(year: Int, month: Int? = nil, day: Int? = nil) {
        precondition(Self.isValid(year: year, month: month, day: day), "Invalid visit date \(year)-\(month ?? 0)-\(day ?? 0)")
        self.year = year
        self.month = month
        self.day = day
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let year = try container.decode(Int.self, forKey: .year)
        let month = try container.decodeIfPresent(Int.self, forKey: .month)
        let day = try container.decodeIfPresent(Int.self, forKey: .day)
        guard Self.isValid(year: year, month: month, day: day) else {
            throw DecodingError.dataCorruptedError(
                forKey: .year, in: container, debugDescription: "Invalid visit date \(year)-\(month ?? 0)-\(day ?? 0)"
            )
        }
        self.init(year: year, month: month, day: day)
    }

    private static func isValid(year: Int, month: Int?, day: Int?) -> Bool {
        guard (1...9999).contains(year) else { return false }
        guard let month else { return day == nil }
        guard (1...12).contains(month) else { return false }
        guard let day else { return true }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        let components = DateComponents(year: year, month: month, day: day)
        return components.isValidDate(in: calendar)
    }

    var precision: Precision {
        if day != nil { .day } else if month != nil { .month } else { .year }
    }

    /// Year-only dates sort before dated ones in the same year, and month-only
    /// before days in that month; reversed (newest first), they come last.
    static func < (a: VisitDate, b: VisitDate) -> Bool {
        (a.year, a.month ?? 0, a.day ?? 0) < (b.year, b.month ?? 0, b.day ?? 0)
    }
}

// MARK: - Formatting

extension Visit {
    /// "June 3, 2024", "June 3 – 7, 2024", "May – June 2019", "2015", …
    /// in the given locale (punctuation and spacing follow the locale).
    nonisolated func formatted(locale: Locale = .autoupdatingCurrent) -> String {
        let formatter = DateIntervalFormatter()
        formatter.locale = locale
        formatter.calendar = VisitDate.calendar
        formatter.timeZone = VisitDate.calendar.timeZone
        formatter.dateTemplate = switch start.precision {
        case .day: "yMMMMd"
        case .month: "yMMMM"
        case .year: "y"
        }
        let startDate = start.date
        return formatter.string(from: startDate, to: end?.date ?? startDate)
    }
}

extension VisitDate {
    /// Gregorian in UTC: the fixed frame visit dates are converted through,
    /// so the result never depends on the device's time zone.
    nonisolated static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }()

    /// Noon UTC on the first day of the date's period.
    nonisolated var date: Date {
        Self.calendar.date(from: DateComponents(year: year, month: month ?? 1, day: day ?? 1, hour: 12))!
    }

    /// The first day of the date's period: itself for a day, the 1st of a
    /// month, or January 1st of a year.
    nonisolated var firstDay: VisitDate {
        VisitDate(year: year, month: month ?? 1, day: day ?? 1)
    }

    /// The last day of the date's period: itself for a day, the end of a
    /// month, or December 31st of a year.
    nonisolated var lastDay: VisitDate {
        if day != nil { return self }
        let month = month ?? 12
        let days = Self.calendar.range(of: .day, in: .month, for: VisitDate(year: year, month: month).date)!.count
        return VisitDate(year: year, month: month, day: days)
    }

    /// The same date at a coarser precision (or unchanged if it's already
    /// that coarse).
    nonisolated func truncated(to precision: Precision) -> VisitDate {
        switch precision {
        case .day: self
        case .month: VisitDate(year: year, month: month)
        case .year: VisitDate(year: year)
        }
    }
}

extension Visit {
    /// Every day the visit covers, from the first day of its start to the
    /// last day of its end, so visits of different precision can be compared.
    nonisolated var days: ClosedRange<VisitDate> {
        start.firstDay...(end ?? start).lastDay
    }
}

extension VisitDate.Precision {
    /// Day is finest, year coarsest.
    nonisolated var coarseness: Int {
        switch self {
        case .day: 0
        case .month: 1
        case .year: 2
        }
    }
}
