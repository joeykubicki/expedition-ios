import SwiftUI

/// Settings → About → Privacy Policy. App Review requires the policy inside
/// the app as well as at a URL. Keep the wording in step with
/// `docs/privacy-policy.html`, the copy hosted on kubickilabs.com.
struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Effective October 31, 2026")
                        .font(.subheadline)
                        .foregroundStyle(Color.inkSoft)
                    Text("Expedition: Travel Atlas is made by Kubicki Labs. The short version: we don't collect any of your data. What you record stays on your devices and in your own iCloud account.")
                }

                section("What We Collect") {
                    Text("Nothing. Expedition has no accounts, analytics, ads, or tracking, and includes no third-party code. Kubicki Labs has no servers that receive your data and can't see anything you record in the app.")
                }

                section("What the App Stores, and Where") {
                    Text("The places you've visited, your bucket list, visit dates, notes, favorites, memories, and photos are stored on your device. If you're signed in to iCloud, they also sync through your private iCloud database so they appear on your other devices. Only you can access that database; Kubicki Labs can't. Apple's privacy policy covers iCloud.")
                    Text("The app also remembers a few settings on your device, such as which tab you had open.")
                }

                section("Photos") {
                    Text("Expedition only receives the photos you choose in the photo picker, not the rest of your library. Before a photo is saved, it's resized and its metadata, including location and camera details, is removed.")
                    Text("When you save a map poster to Photos, the app asks for permission to add images to your library. It can't read your library.")
                }

                section("Maps and Location") {
                    Text("Maps are provided by Apple Maps, so map requests go to Apple under Apple's privacy policy. Expedition never asks for or uses your location.")
                }

                section("Exports, Ratings, and Links") {
                    Text("Exporting your data creates a file that you choose where to send. Photos aren't included.")
                    Text("Requests to rate the app are shown by the App Store. Kubicki Labs doesn't receive any personal information from them.")
                    Text("Links you add, such as trail pages, open in your browser and are covered by those sites' own policies.")
                }

                section("Children") {
                    Text("Expedition doesn't collect data from anyone, including children.")
                }

                section("Deleting Your Data") {
                    Text("You can remove anything you've recorded from within the app. Deleting the app removes its data from your device. To delete the copy in iCloud, open your iCloud storage in the Settings app, choose Expedition, and delete its data.")
                }

                section("Changes") {
                    Text("If this policy changes, the new version will appear here and at kubickilabs.com, with a new effective date.")
                }

                section("Contact") {
                    Text("Questions? Email [support@kubickilabs.com](mailto:support@kubickilabs.com).")
                }
            }
            .foregroundStyle(Color.ink)
            .padding()
            .frame(maxWidth: 700, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(Color.paper)
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func section(_ title: LocalizedStringKey, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            content()
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        PrivacyPolicyView()
    }
}
#endif
