import Foundation

enum AppSection: String, CaseIterable, Identifiable {
    case downloader
    case video
    case image
    case pdf
    case queue

    var id: String { rawValue }

    var title: String {
        switch self {
        case .downloader: return "Downloader"
        case .video: return "Video"
        case .image: return "Image"
        case .pdf: return "PDF"
        case .queue: return "Queue"
        }
    }

    var symbolName: String {
        switch self {
        case .downloader: return "arrow.down.circle"
        case .video: return "video"
        case .image: return "photo"
        case .pdf: return "doc.richtext"
        case .queue: return "list.bullet.rectangle"
        }
    }
}
