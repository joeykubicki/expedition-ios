import SwiftData
import SwiftUI

@main
struct ExpeditionApp: App {
    private let container: Result<ModelContainer, any Error> = Result { try ModelContainerFactory.make() }
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
