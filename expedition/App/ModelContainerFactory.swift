import SwiftData

enum ModelContainerFactory {
    /// The app's SwiftData container. On disk it syncs to the user's private
    /// iCloud database when the iCloud capability is configured and the user
    /// is signed in, and works locally otherwise. In memory (tests and
    /// Previews) it never syncs.
    static func make(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            cloudKitDatabase: inMemory ? .none : .automatic
        )
        return try ModelContainer(
            for: schema,
            migrationPlan: ExpeditionMigrationPlan.self,
            configurations: [configuration]
        )
    }
}
