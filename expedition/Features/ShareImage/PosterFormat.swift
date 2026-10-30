import SwiftUI

/// The shapes a share poster comes in. Both are 2160 pixels wide.
enum PosterFormat: String, CaseIterable, Identifiable {
    /// 4:5, for feeds: 2160 × 2700.
    case post
    /// 9:16, for Stories: 2160 × 3840.
    case story

    static let scale: CGFloat = 5.4

    var id: Self { self }

    /// In points; times `scale` gives the pixel size.
    var size: CGSize {
        switch self {
        case .post: CGSize(width: 400, height: 500)
        case .story: CGSize(width: 400, height: 3840 / Self.scale)
        }
    }

    var title: LocalizedStringResource {
        switch self {
        case .post: "Post"
        case .story: "Story"
        }
    }
}

extension View {
    /// The atlas-plate look every poster shares: parchment, a double rule
    /// around the edge, always light, and Dynamic Type pinned so every shared
    /// image looks the same whatever the device's settings. Stories get
    /// larger type to fill the taller page.
    func posterPlate(_ format: PosterFormat) -> some View {
        frame(width: format.size.width, height: format.size.height)
            .background(Color.paper)
            .overlay {
                Rectangle().strokeBorder(Color.boundary, lineWidth: 1).padding(10)
                Rectangle().strokeBorder(Color.boundary.opacity(0.6), lineWidth: 0.5).padding(14)
            }
            .environment(\.colorScheme, .light)
            .dynamicTypeSize(format == .story ? .xxLarge : .large)
    }
}
