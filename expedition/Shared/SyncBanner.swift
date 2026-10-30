import SwiftUI

/// Small, dismissible card shown on every tab when iCloud sync has a problem
/// the user should know about. Always reassures that data is safe locally.
struct SyncBanner: View {
    let problem: SyncProblem
    let onDismiss: () -> Void

    private var symbolName: String {
        problem == .quotaExceeded ? "exclamationmark.icloud.fill" : "icloud.slash.fill"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbolName)
                .font(.title3)
                .foregroundStyle(Color.visited)
                .accessibilityHidden(true)
            Text(problem.bannerMessage)
                .font(.subheadline)
                .foregroundStyle(Color.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            Button("Dismiss sync message", systemImage: "xmark", action: onDismiss)
                .labelStyle(.iconOnly)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.inkSoft)
                .buttonStyle(.borderless)
        }
        .padding(14)
        .background(.regularMaterial, in: .rect(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.visited.opacity(0.4), lineWidth: 1))
        .padding(.horizontal)
        .padding(.top, 4)
        .accessibilityElement(children: .contain)
        .onAppear {
            AccessibilityNotification.Announcement(problem.bannerMessage).post()
        }
    }
}

#Preview("Storage full") {
    VStack {
        SyncBanner(problem: .quotaExceeded, onDismiss: {})
        Spacer()
    }
    .background(Color.paper)
}

#Preview("Other failure") {
    VStack {
        SyncBanner(problem: .other, onDismiss: {})
        Spacer()
    }
    .background(Color.paper)
}

#Preview("Large text") {
    VStack {
        SyncBanner(problem: .quotaExceeded, onDismiss: {})
        Spacer()
    }
    .background(Color.paper)
    .environment(\.dynamicTypeSize, .accessibility3)
}
