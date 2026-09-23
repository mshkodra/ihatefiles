import Foundation

/// Which download path a pasted URL should take. Centralizes the
/// host-detection logic `DownloaderView` used to branch on inline, so the
/// generic (Phase 8) fallback and the YouTube/Twitter special cases share
/// one place to reason about routing.
enum DownloadRoute: Equatable {
    case youtubeVideo
    case youtubePlaylist
    case twitter
    case generic
}

enum URLSniffer {
    private static let youtubeApexDomains = ["youtube.com", "youtu.be"]

    static func route(for url: String) -> DownloadRoute {
        if TwitterURLDetector.isTwitterURL(url) {
            return .twitter
        }
        if isYouTubeURL(url) {
            return YouTubePlaylistDetector.isPlaylistURL(url) ? .youtubePlaylist : .youtubeVideo
        }
        return .generic
    }

    private static func isYouTubeURL(_ url: String) -> Bool {
        guard let host = URLComponents(string: url)?.host?.lowercased() else { return false }
        return youtubeApexDomains.contains { apex in
            host == apex || host.hasSuffix("." + apex)
        }
    }
}
