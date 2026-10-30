import Foundation

/// Interprets what the user typed into a link field.
nonisolated enum LinkInput: Equatable, Sendable {
    case empty
    case valid(URL)
    case invalid

    /// Trims whitespace and adds `https://` when no scheme was typed, so
    /// "alltrails.com/trail/..." works.
    init(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            self = .empty
            return
        }
        let withScheme = trimmed.contains("://") ? trimmed : "https://" + trimmed
        guard !withScheme.contains(where: \.isWhitespace),
              let url = URL(string: withScheme),
              let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme),
              let host = url.host(), host.contains("."), !host.hasPrefix("."), !host.hasSuffix(".")
        else {
            self = .invalid
            return
        }
        self = .valid(url)
    }
}
