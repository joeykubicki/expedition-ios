import SwiftUI

extension View {
    /// What every tab's root screen shares: the sync problem banner and the
    /// Settings button. Apply inside the tab's `NavigationStack`.
    func tabScreenChrome() -> some View {
        modifier(TabScreenChrome())
    }
}

private struct TabScreenChrome: ViewModifier {
    @Environment(SyncMonitor.self) private var syncMonitor
    @State private var isShowingSettings = false

    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .top) {
                if let problem = syncMonitor.bannerProblem {
                    SyncBanner(problem: problem, onDismiss: syncMonitor.dismissBanner)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.snappy, value: syncMonitor.bannerProblem)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Settings", systemImage: "gearshape") {
                        isShowingSettings = true
                    }
                }
            }
            .sheet(isPresented: $isShowingSettings) {
                SettingsView()
            }
    }
}
