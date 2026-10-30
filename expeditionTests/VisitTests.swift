import Foundation
import Testing
@testable import expedition

struct VisitDateTests {
    @Test func precisionFollowsWhatIsKnown() {
        #expect(VisitDate(year: 2024, month: 6, day: 3).precision == .day)
        #expect(VisitDate(year: 2024, month: 6).precision == .month)
        #expect(VisitDate(year: 2024).precision == .year)
    }

    @Test func ordersChronologicallyWithVaguerDatesFirstInTheirPeriod() {
        let dates = [
            VisitDate(year: 2024, month: 6, day: 3),
            VisitDate(year: 2023),
            VisitDate(year: 2024),
            VisitDate(year: 2024, month: 6),
            VisitDate(year: 2024, month: 1, day: 20),
        ]
        #expect(dates.sorted() == [
            VisitDate(year: 2023),
            VisitDate(year: 2024),
            VisitDate(year: 2024, month: 1, day: 20),
            VisitDate(year: 2024, month: 6),
            VisitDate(year: 2024, month: 6, day: 3),
        ])
    }

    @Test func encodesOnlyWhatIsKnown() throws {
        let json = try String(decoding: JSONEncoder().encode(VisitDate(year: 2015)), as: UTF8.self)
        #expect(json == #"{"year":2015}"#)
    }
}

struct VisitFormattingTests {
    let english = Locale(identifier: "en_US")

    /// Interval formatters use thin and narrow spaces around the dash;
    /// normalize them so the expectations stay readable.
    private func format(_ visit: Visit) -> String {
        visit.formatted(locale: english)
            .replacingOccurrences(of: "\u{2009}", with: " ")
            .replacingOccurrences(of: "\u{202F}", with: " ")
    }

    @Test func singleDates() {
        #expect(format(Visit(start: VisitDate(year: 2024, month: 6, day: 3))) == "June 3, 2024")
        #expect(format(Visit(start: VisitDate(year: 2024, month: 6))) == "June 2024")
        #expect(format(Visit(start: VisitDate(year: 2015))) == "2015")
    }

    @Test func ranges() {
        let days = Visit(start: VisitDate(year: 2024, month: 6, day: 3), end: VisitDate(year: 2024, month: 6, day: 7))
        let acrossMonths = Visit(start: VisitDate(year: 2024, month: 5, day: 30), end: VisitDate(year: 2024, month: 6, day: 2))
        let months = Visit(start: VisitDate(year: 2019, month: 5), end: VisitDate(year: 2019, month: 6))
        let years = Visit(start: VisitDate(year: 2015), end: VisitDate(year: 2017))

        #expect(format(days) == "June 3 – 7, 2024")
        #expect(format(acrossMonths) == "May 30 – June 2, 2024")
        #expect(format(months) == "May – June 2019")
        #expect(format(years) == "2015 – 2017")
    }

    /// The point of storing year/month/day: the same visit reads the same in
    /// every time zone.
    @Test func ignoresTheDeviceTimeZone() {
        let visit = Visit(start: VisitDate(year: 2024, month: 1, day: 1))
        let formatted = format(visit)
        let original = NSTimeZone.default
        defer { NSTimeZone.default = original }
        for zone in ["Pacific/Kiritimati", "Pacific/Pago_Pago", "Asia/Tokyo"] {
            NSTimeZone.default = TimeZone(identifier: zone)!
            #expect(format(visit) == formatted, "\(zone)")
        }
    }
}

struct VisitDraftTests {
    private func calendar(_ zone: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: zone)!
        return calendar
    }

    @Test func newDraftIsTodayInTheDevicesCalendar() {
        // 2024-06-03 05:00 UTC is still June 2 in Los Angeles.
        let instant = Date(timeIntervalSince1970: 1_717_390_800)
        #expect(VisitDraft(today: instant, calendar: calendar("America/Los_Angeles")).startDate == VisitDate(year: 2024, month: 6, day: 2))
        #expect(VisitDraft(today: instant, calendar: calendar("Asia/Tokyo")).startDate == VisitDate(year: 2024, month: 6, day: 3))
    }

    @Test func truncatesToThePrecision() throws {
        var draft = VisitDraft(today: Date(timeIntervalSince1970: 1_717_416_000), calendar: calendar("UTC"))
        draft.precision = .month
        #expect(try #require(draft.visit()).start == VisitDate(year: 2024, month: 6))
        draft.precision = .year
        #expect(try #require(draft.visit()).start == VisitDate(year: 2024))
    }

    @Test func endEqualToStartSavesAsASingleDate() throws {
        var draft = VisitDraft(today: Date(timeIntervalSince1970: 1_717_416_000), calendar: calendar("UTC"))
        draft.hasEnd = true
        draft.end.day += 4
        draft.precision = .month

        #expect(try #require(draft.visit()).end == nil, "June 3 – 7 is just June at month precision")
    }

    @Test func endBeforeStartIsInvalid() {
        var draft = VisitDraft(today: Date(timeIntervalSince1970: 1_717_416_000), calendar: calendar("UTC"))
        draft.hasEnd = true
        draft.end.year -= 1

        #expect(!draft.isValid)
        #expect(draft.visit() == nil)
    }

    @Test func switchingMonthsClampsTheDay() throws {
        var draft = VisitDraft(Visit(start: VisitDate(year: 2023, month: 1, day: 31)))
        draft.precision = .month
        draft.start.month = 2
        draft.precision = .day

        #expect(try #require(draft.visit()).start == VisitDate(year: 2023, month: 2, day: 28))
    }

    @Test func editingKeepsTheVisitsDates() throws {
        let visit = Visit(start: VisitDate(year: 2019, month: 5), end: VisitDate(year: 2019, month: 6))
        let draft = VisitDraft(visit)

        #expect(draft.precision == .month)
        #expect(draft.visit(id: visit.id) == visit)
    }
}
