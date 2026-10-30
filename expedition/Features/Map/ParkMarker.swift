import SwiftUI

/// Tree marker for a park: outlined when unvisited, filled with a checkmark
/// badge when visited (so it never relies on color alone).
struct ParkMarker: View {
    let isVisited: Bool
    let isSelected: Bool

    var body: some View {
        Image(systemName: "tree.fill")
            .font(.caption)
            .foregroundStyle(isVisited ? Color.white : Color.parkVisited)
            .padding(4)
            .background(isVisited ? Color.parkVisited : Color.paper, in: .circle)
            .overlay(Circle().strokeBorder(Color.parkVisited, lineWidth: isSelected ? 3 : 1.5))
            .visitedBadge(isVisited)
            .scaleEffect(isSelected ? 1.25 : 1)
            .animation(.snappy, value: isSelected)
    }
}

/// Several parks too close to tell apart at this zoom: a tree and a count.
/// Filled with a checkmark badge when every park in it is visited; a
/// "✓ 2" badge counts the visited ones otherwise.
struct ParkClusterMarker: View {
    let count: Int
    let visitedCount: Int

    private var allVisited: Bool { visitedCount == count }

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "tree.fill")
            Text(count, format: .number)
                .monospacedDigit()
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(allVisited ? Color.white : Color.parkVisited)
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background(allVisited ? Color.parkVisited : Color.paper, in: .capsule)
        .overlay(Capsule().strokeBorder(Color.parkVisited, lineWidth: 1.5))
        .visitedBadge(allVisited)
        .overlay(alignment: .topTrailing) {
            if visitedCount > 0, !allVisited {
                visitedCountBadge
            }
        }
    }

    private var visitedCountBadge: some View {
        HStack(spacing: 1) {
            Image(systemName: "checkmark")
                .imageScale(.small)
            Text(visitedCount, format: .number)
                .monospacedDigit()
        }
        .font(.caption2.weight(.bold))
        .foregroundStyle(Color.white)
        .padding(.horizontal, 4)
        .padding(.vertical, 1)
        .background(Color.parkVisited, in: .capsule)
        .overlay(Capsule().strokeBorder(Color.paper, lineWidth: 1))
        .offset(x: 8, y: -8)
    }
}

private extension View {
    func visitedBadge(_ isVisited: Bool) -> some View {
        overlay(alignment: .topTrailing) {
            if isVisited {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption2.weight(.bold))
                    .imageScale(.small)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(Color.white, Color.ink)
                    .offset(x: 4, y: -4)
            }
        }
    }
}

#Preview {
    HStack(spacing: 24) {
        ParkMarker(isVisited: false, isSelected: false)
        ParkMarker(isVisited: true, isSelected: false)
        ParkMarker(isVisited: true, isSelected: true)
        ParkClusterMarker(count: 3, visitedCount: 1)
        ParkClusterMarker(count: 5, visitedCount: 5)
    }
    .padding()
    .background(Color.land)
}
