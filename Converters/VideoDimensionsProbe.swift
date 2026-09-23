import Foundation

/// Determines a video's pixel dimensions using the bundled ffmpeg, the same
/// way `VideoDurationProbe` determines duration: running ffmpeg with `-i` and
/// no output always exits non-zero, but along the way it prints a
/// `Video: ... WIDTHxHEIGHT ...` line to stderr, which is parsed here instead
/// of requiring a vendored `ffprobe` (none is bundled — see
/// `Resources/VERSIONS.md`). Used by `VideoOverlayRunner` to size and
/// position the picture-in-picture overlay.
enum VideoDimensionsProbe {
    struct ProbeError: LocalizedError {
        var errorDescription: String? { "Could not determine the video's dimensions." }
    }

    static func dimensions(of url: URL) async throws -> (width: Int, height: Int) {
        let ffmpegURL = try BinaryLocator.ffmpegURL
        do {
            try await ProcessRunning.run(
                executableURL: ffmpegURL,
                arguments: ["-i", url.path],
                onStdoutLine: { _ in }
            )
            // ffmpeg with -i and no output always exits non-zero; reaching
            // here means it didn't, which is unexpected.
            throw ProbeError()
        } catch let error as ProcessRunning.ProcessError {
            guard let dimensions = parseDimensions(from: error.stderrOutput) else {
                throw ProbeError()
            }
            return dimensions
        }
    }

    /// ffmpeg prints a video stream's size as a bare `WIDTHxHEIGHT` token on
    /// its "Stream #...: Video: ..." line, e.g. "1920x1080 [SAR 1:1 DAR
    /// 16:9]". Finds the first such token after "Video: ".
    static func parseDimensions(from ffmpegOutput: String) -> (width: Int, height: Int)? {
        guard let videoRange = ffmpegOutput.range(of: "Video: ") else { return nil }
        let after = ffmpegOutput[videoRange.upperBound...]
        guard let match = after.firstMatch(of: /(\d+)x(\d+)/),
              let width = Int(match.1), let height = Int(match.2)
        else { return nil }
        return (width, height)
    }
}
