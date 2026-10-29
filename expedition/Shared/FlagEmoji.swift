import Foundation

nonisolated enum FlagEmoji {
    /// The flag emoji for an ISO 3166-1 alpha-2 code (`JP` → 🇯🇵), or `nil`
    /// if the code isn't two ASCII letters.
    static func forRegionCode(_ code: String) -> String? {
        let letters = code.uppercased().unicodeScalars
        guard letters.count == 2, letters.allSatisfy({ ("A"..."Z").contains($0) }) else { return nil }
        let regionalIndicatorA: UInt32 = 0x1F1E6
        let scalars = letters.compactMap { Unicode.Scalar(regionalIndicatorA + $0.value - 65) }
        return String(String.UnicodeScalarView(scalars))
    }
}
