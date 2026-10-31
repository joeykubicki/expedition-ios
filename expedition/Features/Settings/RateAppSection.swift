import SwiftUI

enum AppStoreLink {
    /// The app's Apple ID from App Store Connect (App Information → General
    /// Information → Apple ID). Settings → Rate Expedition is hidden when
    /// this is `nil`.
    static let appID: String? = "6829112861"

    static var writeReview: URL? {
        appID.flatMap { URL(string: "https://apps.apple.com/app/id\($0)?action=write-review") }
    }
}

/// Settings → Rate Expedition: opens the App Store's review page. Shown only
/// once there's an App Store ID to link to.
struct RateAppSection: View {
    var url: URL? = AppStoreLink.writeReview

    var body: some View {
        if let url {
            Section {
                Link(destination: url) {
                    Label("Rate Expedition", systemImage: "star")
                }
                .accessibilityHint("Opens the App Store to rate and review Expedition")
            }
        }
    }
}

#if DEBUG
#Preview {
    Form {
        RateAppSection(url: URL(string: "https://apps.apple.com/app/id0?action=write-review"))
    }
}
#endif
