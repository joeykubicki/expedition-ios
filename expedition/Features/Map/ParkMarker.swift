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
            .overlay(alignment: .topTrailing) {
                if isVisited {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 9, weight: .bold))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(Color.white, Color.ink)
                        .offset(x: 4, y: -4)
                }
            }
            .scaleEffect(isSelected ? 1.25 : 1)
            .animation(.snappy, value: isSelected)
    }
}

#Preview {
    HStack(spacing: 24) {
        ParkMarker(isVisited: false, isSelected: false)
        ParkMarker(isVisited: true, isSelected: false)
        ParkMarker(isVisited: true, isSelected: true)
    }
    .padding()
    .background(Color.land)
}
