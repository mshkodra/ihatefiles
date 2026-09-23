import Foundation

/// Determines a video's duration using the bundled ffmpeg, since no ffprobe
/// binary is vendored (see Resources/VERSIONS.md — the osxexperts.net build
/// used for Phase 3 ships ffmpeg only). Running ffmpeg with `-i` and no
/// output always exits non-zero, but it prints a `Duration: HH:MM:SS.ss`
/// line to stderr while probing the input first — that's parsed here
/// instead of requiring a second vendored binary. Reused by Phase 10's
/// split/concat runners.
enum VideoDurationProbe {
    struct ProbeError: LocalizedError {
        var errorDescription: String? { "Could not determine the video's duration." }
    }

    static func duration(of url: URL) async throws -> TimeInterval {
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
            guard let duration = parseDuration(from: error.stderrOutput) else {
                throw ProbeError()
            }
            return duration
        }
    }

    static func parseDuration(from ffmpegOutput: String) -> TimeInterval? {
        guard let range = ffmpegOutput.range(of: "Duration: ") else { return nil }
        let after = ffmpegOutput[range.upperBound...]
        guard let comma = after.firstIndex(of: ",") else { return nil }
        let parts = after[after.startIndex..<comma].split(separator: ":")
        guard parts.count == 3,
              let hours = Double(parts[0]),
              let minutes = Double(parts[1]),
              let seconds = Double(parts[2])
        else { return nil }
        return hours * 3600 + minutes * 60 + seconds
    }
}
