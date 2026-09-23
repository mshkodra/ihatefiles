import Foundation

enum JobKind: String, Codable, Sendable {
    case youtubeVideo
    case youtubePlaylist
    case twitter
    case genericURL
    case videoConvert
    case videoSplit
    case videoConcat
    case videoOverlay
    case imageConvert
    case pdfMerge

    /// Downloads are subject to JobManager's concurrency cap; conversions always run immediately.
    var isDownload: Bool {
        switch self {
        case .youtubeVideo, .youtubePlaylist, .twitter, .genericURL:
            return true
        case .videoConvert, .videoSplit, .videoConcat, .videoOverlay, .imageConvert, .pdfMerge:
            return false
        }
    }
}
