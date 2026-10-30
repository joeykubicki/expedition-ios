import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SyncMonitor.self) private var syncMonitor

    private var version: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SyncStatusRow(status: syncMonitor.state.status)
                } header: {
                    Text("iCloud Sync")
                } footer: {
                    Text("Your places sync to your private iCloud account. They're always saved on this iPhone too.")
                }
                DataTransferSection()
                Section("About") {
                    LabeledContent("Version", value: version)
                    Text("Map data from Natural Earth.")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#if DEBUG
#Preview {
    SettingsView()
        .previewEnvironment()
}
#endif
