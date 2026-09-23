import Foundation

/// Detects whether a URL points at Twitter/X, routing it to the probe →
/// format-picker → download flow instead of the YouTube path.
enum TwitterURLDetector {
    private static let apexDomains = ["twitter.com", "x.com"]

    static func isTwitterURL(_ url: String) -> Bool {
        guard let host = URLComponents(string: url)?.host?.lowercased() else { return false }
        return apexDomains.contains { apex in
            host == apex || host.hasSuffix("." + apex)
        }
    }
}
