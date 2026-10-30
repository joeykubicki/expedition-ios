import SwiftData
import SwiftUI

/// The year-in-review share image: the year, its stats, a map of that
/// year's places, and its trips, on the same atlas plate as `MapPoster`.
struct YearPoster: View {
    let review: YearReview
    let format: PosterFormat
    let map: PosterMap

    init(review: YearReview, format: PosterFormat, referenceData: ReferenceDataStore) {
        self.review = review
        self.format = format
        map = PosterMap.year(review.places, states: referenceData.states, countries: referenceData.countries) { isUnitedStates in
            switch (format, isUnitedStates) {
            case (.post, true): 290
            case (.post, false): 340
            case (.story, true): 356
            case (.story, false): 368
            }
        }
    }

    /// Trips that fit before "+N more trips".
    var maxTrips: Int {
        format == .story ? 10 : 4
    }

    /// Room for "May–Jun" at each format's type size.
    private var whenWidth: CGFloat {
        format == .story ? 76 : 56
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: format == .story ? 20 : 12) {
                header
                stats
            }
            .padding(.horizontal, 30)
            .padding(.top, format == .story ? 60 : 30)
            Spacer(minLength: 8)
            PosterMapCanvas(map: map)
                .frame(width: map.size.width, height: map.size.height)
            if !map.outlying.isEmpty {
                outlyingParks
                    .frame(width: map.size.width, alignment: .trailing)
                    .padding(.top, 4)
            }
            Spacer(minLength: 8)
            VStack(alignment: .leading, spacing: format == .story ? 20 : 10) {
                trips
                footer
            }
            .padding(.horizontal, 30)
            .padding(.bottom, format == .story ? 52 : 26)
        }
        .posterPlate(format)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("EXPEDITION")
                .font(.caption2.weight(.semibold))
                .tracking(2)
                .foregroundStyle(Color.inkSoft)
            Text(verbatim: String(review.year))
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(Color.ink)
            Text("A Year of Travel")
                .font(.title3)
                .foregroundStyle(Color.inkSoft)
        }
        .fontDesign(.serif)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var stats: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 0) {
                ForEach(statTiles, id: \.label) { tile in
                    VStack(spacing: 1) {
                        Text(tile.value, format: .number)
                            .font(.title2.weight(.bold))
                            .fontDesign(.serif)
                            .foregroundStyle(tile.color)
                        Text(tile.label)
                            .font(.caption2.weight(.semibold))
                            .textCase(.uppercase)
                            .foregroundStyle(Color.inkSoft)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            if let extras {
                Text(extras)
                    .font(.footnote)
                    .foregroundStyle(Color.ink)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var statTiles: [(value: Int, label: String, color: Color)] {
        var tiles: [(value: Int, label: String, color: Color)] = [
            (review.placeCount, review.placeCount == 1 ? String(localized: "Place") : String(localized: "Places"), .ink),
            (review.newPlaceCount, String(localized: "New"), .visited),
        ]
        if review.countryCount > 0 {
            tiles.append((review.countryCount, review.countryCount == 1 ? String(localized: "Country") : String(localized: "Countries"), .ink))
        }
        if review.stateCount > 0 {
            tiles.append((review.stateCount, review.stateCount == 1 ? String(localized: "State") : String(localized: "States"), .ink))
        }
        if review.parkCount > 0 {
            tiles.append((review.parkCount, review.parkCount == 1 ? String(localized: "Park") : String(localized: "Parks"), .parkVisited))
        }
        return tiles
    }

    /// "23 days on the road · Longest trip: Japan, 11 days"
    private var extras: String? {
        var parts: [String] = []
        if review.daysOnTheRoad > 0 {
            parts.append(String(localized: "\(review.daysOnTheRoad) days on the road"))
        }
        if let longest = review.longestTrip {
            parts.append(String(localized: "Longest trip: \(longest.names.formatted(.list(type: .and))), \(longest.days) days"))
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private var trips: some View {
        VStack(alignment: .leading, spacing: format == .story ? 7 : 4) {
            ForEach(review.tripLines.prefix(maxTrips)) { line in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(line.when)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.inkSoft)
                        .lineLimit(1)
                        .frame(width: whenWidth, alignment: .leading)
                    Text(line.stops.map { $0.isFirstVisit ? "★ \($0.name)" : $0.name }.formatted(.list(type: .and)))
                        .font(.subheadline)
                        .foregroundStyle(Color.ink)
                        .lineLimit(format == .story ? 2 : 1)
                }
            }
            let more = review.tripLines.count - maxTrips
            if more > 0 {
                Text("+\(more) more trips")
                    .font(.caption)
                    .foregroundStyle(Color.inkSoft)
                    .padding(.leading, whenWidth + 10)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var outlyingParks: some View {
        HStack(spacing: 10) {
            ForEach(map.outlying, id: \.place.id) { park in
                HStack(spacing: 4) {
                    PosterDot(isVisited: true, color: .parkVisited, radius: map.dotRadius)
                    Text(park.place.name)
                        .font(.caption2)
                        .foregroundStyle(Color.inkSoft)
                }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 14) {
            PosterLegendItem(category: .country, isVisited: true, dotRadius: map.dotRadius, label: "Visited in \(String(review.year))")
            if map.dots.contains(where: { $0.placeID.category == .park }) {
                PosterLegendItem(category: .park, isVisited: true, dotRadius: map.dotRadius, label: "Park")
            }
            Text("★ First visit")
                .font(.caption)
                .foregroundStyle(Color.ink)
            Spacer(minLength: 0)
        }
    }
}

#if DEBUG
private struct YearPosterPreview: View {
    let year: Int
    var format = PosterFormat.post
    @Environment(ReferenceDataStore.self) private var referenceData
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        let entries = (try? modelContext.fetch(FetchDescriptor<PlaceEntry>())) ?? []
        let timeline = Timeline(entries: entries, category: nil, place: referenceData.place(for:))
        if let year = timeline.years.first(where: { $0.year == year }) {
            YearPoster(review: YearReview(year: year), format: format, referenceData: referenceData)
                .scaleEffect(format == .story ? 0.55 : 0.8)
        }
    }
}

#Preview("2023, US") {
    YearPosterPreview(year: 2023)
        .previewEnvironment()
}

#Preview("2019, world") {
    YearPosterPreview(year: 2019)
        .previewEnvironment()
}

#Preview("Story") {
    YearPosterPreview(year: 2023, format: .story)
        .previewEnvironment()
}
#endif
