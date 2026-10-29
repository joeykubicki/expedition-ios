import SwiftData
import SwiftUI

@main
struct ExpeditionApp: App {
    private let container: Result<ModelContainer, any Error> = Result {
        #if DEBUG
        // Launch with `-UseSampleData` for an in-memory store with sample
        // visits (for simulator screenshots); never touches real data.
        if ProcessInfo.processInfo.arguments.contains("-UseSampleData") {
            return PreviewSupport.container()
        }
        #endif
        return try ModelContainerFactory.make()
    }
    @State private var referenceData = ReferenceDataStore()

    var body: some Scene {
        WindowGroup {
            switch container {
            case .success(let container):
                RootView()
                    .environment(referenceData)
                    .modelContainer(container)
            case .failure(let error):
                StartupErrorView(error: error)
            }
        }
    }
}
