import Foundation

/// Detects whether a YouTube URL points at a playlist (a `list=` query
/// parameter) — including a single video opened from within a playlist,
/// which is still routed through playlist handling.
enum YouTubePlaylistDetector {
    static func isPlaylistURL(_ url: String) -> Bool {
        guard let components = URLComponents(string: url) else { return false }
        return components.queryItems?.contains {
            $0.name == "list" && !($0.value ?? "").isEmpty
        } ?? false
    }
}
