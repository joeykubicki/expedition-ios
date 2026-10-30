import SwiftUI

/// Tree marker for a park: outlined when unvisited, filled with a checkmark
/// badge when visited, and dashed with a bookmark badge when on the bucket
/// list (so it never relies on color alone).
struct ParkMarker: View {
    let isVisited: Bool
    var isOnBucketList = false
    let isSelected: Bool

    private var wantsToVisit: Bool { isOnBucketList && !isVisited }

    var body: some View {
        Image(systemName: "tree.fill")
            .font(.caption)
            .foregroundStyle(isVisited ? Color.white : Color.parkVisited)
            .padding(4)
            .background(isVisited ? Color.parkVisited : wantsToVisit ? Color.visitedSoft : Color.paper, in: .circle)
            .overlay(
                Circle().strokeBorder(
                    Color.parkVisited,
                    style: StrokeStyle(lineWidth: isSelected ? 3 : 1.5, dash: wantsToVisit && !isSelected ? [3, 2] : [])
                )
            )
            .visitedBadge(isVisited)
            .bucketListBadge(wantsToVisit)
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
    var bucketListCount = 0

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
        .overlay(alignment: .topLeading) {
            if bucketListCount > 0 {
                bucketListCountBadge
            }
        }
    }

    private var bucketListCountBadge: some View {
        HStack(spacing: 1) {
            Image(systemName: "bookmark.fill")
                .imageScale(.small)
            Text(bucketListCount, format: .number)
                .monospacedDigit()
        }
        .font(.caption2.weight(.bold))
        .foregroundStyle(Color.white)
        .padding(.horizontal, 4)
        .padding(.vertical, 1)
        .background(Color.visitedDeep, in: .capsule)
        .overlay(Capsule().strokeBorder(Color.paper, lineWidth: 1))
        .offset(x: -8, y: -8)
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
    func bucketListBadge(_ isOnBucketList: Bool) -> some View {
        overlay(alignment: .topTrailing) {
            if isOnBucketList {
                Image(systemName: "bookmark.circle.fill")
                    .font(.caption2.weight(.bold))
                    .imageScale(.small)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(Color.white, Color.visitedDeep)
                    .offset(x: 4, y: -4)
            }
        }
    }

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
        ParkMarker(isVisited: false, isOnBucketList: true, isSelected: false)
        ParkClusterMarker(count: 3, visitedCount: 1)
        ParkClusterMarker(count: 4, visitedCount: 1, bucketListCount: 2)
        ParkClusterMarker(count: 5, visitedCount: 5)
    }
    .padding()
    .background(Color.land)
}
