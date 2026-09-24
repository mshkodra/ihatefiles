import Foundation

enum JobKind: String, Codable, Sendable {
    case youtubeVideo
    case youtubeAudio
    case youtubeThumbnail
    case youtubePlaylist
    case twitter
    case genericURL
    case videoConvert
    case videoSplit
    case videoConcat
    case videoOverlay
    case imageConvert
    case pdfMerge
    case pdfSplit
    case pdfRotate
    case pdfExtract
    case pdfCompress
    case pdfImageToPDF

    /// Downloads are subject to JobManager's concurrency cap; conversions always run immediately.
    var isDownload: Bool {
        switch self {
        case .youtubeVideo, .youtubeAudio, .youtubeThumbnail, .youtubePlaylist, .twitter, .genericURL:
            return true
        case .videoConvert, .videoSplit, .videoConcat, .videoOverlay, .imageConvert,
             .pdfMerge, .pdfSplit, .pdfRotate, .pdfExtract, .pdfCompress, .pdfImageToPDF:
            return false
        }
    }
}
