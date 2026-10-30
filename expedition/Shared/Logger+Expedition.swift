import OSLog

extension Logger {
    nonisolated static let data = Logger(subsystem: "com.kubickilabs.expedition", category: "data")
    nonisolated static let sync = Logger(subsystem: "com.kubickilabs.expedition", category: "sync")
}
