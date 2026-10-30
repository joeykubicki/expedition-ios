import SwiftUI

/// One trip on the Timeline or year map: a plain row for a single visit, a
/// card for places visited on overlapping dates.
struct TimelineTripRow: View {
    let trip: Timeline.Trip
    let onSelect: (Place) -> Void

    var body: some View {
        if trip.isSingle {
            let item = trip.items[0]
            PlaceSummaryRow(
                place: item.place,
                detail: item.visit.formatted(),
                isReturnVisit: item.isReturn,
                hint: "Shows details and memories"
            ) {
                onSelect(item.place)
            }
        } else {
            TripCard(trip: trip, onSelect: onSelect)
        }
    }
}

/// Places visited on overlapping dates: the trip's dates, then each place
/// (with its own dates when they differ), each opening its details.
private struct TripCard: View {
    let trip: Timeline.Trip
    let onSelect: (Place) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Label(trip.span.formatted(), systemImage: "suitcase.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.ink)
                Spacer()
                Text("Trip")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.inkSoft)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Trip, \(trip.span.formatted()), \(trip.items.count) places")
            .accessibilityAddTraits(.isHeader)

            VStack(alignment: .leading, spacing: 12) {
                ForEach(trip.items) { item in
                    PlaceSummaryRow(
                        place: item.place,
                        detail: coversTheWholeTrip(item) ? item.place.category.eyebrow : item.visit.formatted(),
                        isReturnVisit: item.isReturn,
                        accessibilityContext: context(for: item),
                        hint: "Shows details and memories"
                    ) {
                        onSelect(item.place)
                    }
                }
            }
            .padding(.leading, 12)
            .overlay(alignment: .leading) {
                Capsule()
                    .fill(Color.boundary)
                    .frame(width: 2)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .contain)
    }

    private func coversTheWholeTrip(_ item: Timeline.Item) -> Bool {
        item.visit.start == trip.span.start && item.visit.end == trip.span.end
    }

    /// "October 12–15, 2023, trip with Utah", so each place reads on its own.
    private func context(for item: Timeline.Item) -> String {
        let others = trip.items.map(\.place).filter { $0.id != item.place.id }
        var names: [String] = []
        for place in others where !names.contains(place.name) {
            names.append(place.name)
        }
        let dates = coversTheWholeTrip(item) ? "\(trip.span.formatted()), " : ""
        return String(localized: "\(dates)trip with \(names.formatted(.list(type: .and)))")
    }
}
