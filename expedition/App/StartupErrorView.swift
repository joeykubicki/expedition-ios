import SwiftUI

/// Shown instead of the app if the on-device database can't be opened.
struct StartupErrorView: View {
    let error: any Error

    var body: some View {
        ContentUnavailableView {
            Label("Couldn't Open Your Data", systemImage: "externaldrive.badge.exclamationmark")
        } description: {
            Text("Expedition couldn't open its saved data on this device. Try restarting your iPhone. If you use iCloud, your places are also stored there.")
        } actions: {
            Text(error.localizedDescription)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
    }
}

#Preview {
    StartupErrorView(error: CocoaError(.fileReadCorruptFile))
}
