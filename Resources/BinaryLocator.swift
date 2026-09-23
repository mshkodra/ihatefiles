import Foundation

/// Resolves the file-system location of the bundled yt-dlp and ffmpeg
/// binaries at runtime. Both are copied into `Contents/Resources/` by the
/// app's Copy Files build phase; see `Resources/Scripts/fetch-binaries.sh`.
enum BinaryLocator {
    enum BinaryLocatorError: LocalizedError {
        case missing(name: String)

        var errorDescription: String? {
            switch self {
            case .missing(let name):
                return "\(name) binary not found in the app bundle — run Resources/Scripts/fetch-binaries.sh and rebuild."
            }
        }
    }

    static var ytDlpURL: URL {
        get throws {
            try resolve(name: "yt-dlp")
        }
    }

    static var ffmpegURL: URL {
        get throws {
            try resolve(name: "ffmpeg")
        }
    }

    private static func resolve(name: String) throws -> URL {
        guard let url = Bundle.main.url(forResource: name, withExtension: nil, subdirectory: "bin") else {
            throw BinaryLocatorError.missing(name: name)
        }
        return url
    }
}
