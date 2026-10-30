import Foundation

/// What the visit form edits: full year/month/day for both ends, whatever the
/// precision, so switching precision back and forth loses nothing. Becomes a
/// `Visit` (truncated to the chosen precision) on save.
nonisolated struct VisitDraft: Equatable, Sendable {
    struct Parts: Equatable, Sendable {
        var year: Int
        var month: Int
        var day: Int
    }

    var precision: VisitDate.Precision
    var start: Parts
    var hasEnd: Bool
    var end: Parts

    /// A new visit: today, to the day, in the device's calendar.
    init(today: Date, calendar: Calendar = .current) {
        let parts = Self.parts(of: today, calendar: calendar)
        precision = .day
        start = parts
        hasEnd = false
        end = parts
    }

    /// An existing visit; missing month or day default to the first.
    init(_ visit: Visit) {
        precision = visit.start.precision
        start = Parts(visit.start)
        hasEnd = visit.end != nil
        end = visit.end.map(Parts.init) ?? start
    }

    var startDate: VisitDate { start.truncated(to: precision) }
    var endDate: VisitDate? { hasEnd ? end.truncated(to: precision) : nil }

    /// An end before the start can't be saved. (An end equal to the start is
    /// fine; it just saves as a single date.)
    var isValid: Bool {
        guard let endDate else { return true }
        return endDate >= startDate
    }

    func visit(id: UUID = UUID()) -> Visit? {
        guard isValid else { return nil }
        let end = endDate.flatMap { $0 == startDate ? nil : $0 }
        return Visit(id: id, start: startDate, end: end)
    }

    static func parts(of date: Date, calendar: Calendar) -> Parts {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return Parts(year: components.year!, month: components.month!, day: components.day!)
    }
}

extension VisitDraft.Parts {
    nonisolated init(_ date: VisitDate) {
        self.init(year: date.year, month: date.month ?? 1, day: date.day ?? 1)
    }

    /// For the day picker: midnight on this day in `calendar`, so the picker
    /// shows the same day the user chose.
    nonisolated func date(in calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: min(day, daysInMonth)))!
    }

    private nonisolated var daysInMonth: Int {
        let firstOfMonth = VisitDate(year: year, month: month).date
        return VisitDate.calendar.range(of: .day, in: .month, for: firstOfMonth)!.count
    }

    /// The day is clamped to the month's length: picking January 31, then
    /// switching to month precision and choosing February, means February 29
    /// (or 28) if you switch back to days.
    nonisolated func truncated(to precision: VisitDate.Precision) -> VisitDate {
        switch precision {
        case .day: VisitDate(year: year, month: month, day: min(day, daysInMonth))
        case .month: VisitDate(year: year, month: month)
        case .year: VisitDate(year: year)
        }
    }
}
