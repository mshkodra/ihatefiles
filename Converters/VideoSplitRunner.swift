import Foundation

/// Splits a video into two parts at `splitSeconds`, via two stream-copy
/// ffmpeg calls (no re-encode, so splits snap to the nearest keyframe — an
/// inherent limitation of `-c copy`, not a bug). Matches the original
/// `split_video.py`'s argument order exactly, including `-ss` placed after
/// `-i` on the second call (slow/accurate seek) rather than before it.
final class VideoSplitRunner: JobRunner, @unchecked Sendable {
    struct ValidationError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    private let inputURL: URL
    private let splitSeconds: Double
    private let firstOutputURL: URL
    private let secondOutputURL: URL
    private let cancellable = CancellableProcess()

    init(inputURL: URL, splitSeconds: Double, firstOutputURL: URL, secondOutputURL: URL) {
        self.inputURL = inputURL
        self.splitSeconds = splitSeconds
        self.firstOutputURL = firstOutputURL
        self.secondOutputURL = secondOutputURL
    }

    func run(job: Job, progress: @escaping @Sendable (Double) -> Void) async throws {
        if cancellable.isCancelled { throw CancellationError() }

        let ffmpegURL = try BinaryLocator.ffmpegURL
        let duration = try await VideoDurationProbe.duration(of: inputURL)
        guard splitSeconds > 0, splitSeconds < duration else {
            throw ValidationError(message: "Split point must fall within the video's \(Int(duration))s duration.")
        }
        if cancellable.isCancelled { throw CancellationError() }

        // First half: 0..<splitSeconds, reported as the first 0...0.5 of progress.
        let firstParser = FfmpegProgressParser(totalDuration: splitSeconds)
        try await runFfmpeg(
            ffmpegURL: ffmpegURL,
            arguments: ["-i", inputURL.path, "-t", "\(splitSeconds)", "-c", "copy", "-progress", "pipe:1", "-y", firstOutputURL.path],
            parser: firstParser,
            progress: progress,
            progressOffset: 0, progressScale: 0.5
        )
        if cancellable.isCancelled { throw CancellationError() }

        // Second half: splitSeconds..<duration, reported as the remaining 0.5...1.0.
        let secondParser = FfmpegProgressParser(totalDuration: duration - splitSeconds)
        try await runFfmpeg(
            ffmpegURL: ffmpegURL,
            arguments: ["-i", inputURL.path, "-ss", "\(splitSeconds)", "-c", "copy", "-progress", "pipe:1", "-y", secondOutputURL.path],
            parser: secondParser,
            progress: progress,
            progressOffset: 0.5, progressScale: 0.5
        )
    }

    private func runFfmpeg(
        ffmpegURL: URL,
        arguments: [String],
        parser: FfmpegProgressParser,
        progress: @escaping @Sendable (Double) -> Void,
        progressOffset: Double, progressScale: Double
    ) async throws {
        do {
            try await ProcessRunning.run(
                executableURL: ffmpegURL,
                arguments: arguments,
                onLaunch: { [cancellable] process in
                    cancellable.store(process)
                },
                onStdoutLine: { line in
                    if let value = parser.ingest(line: line) {
                        progress(progressOffset + value * progressScale)
                    }
                }
            )
        } catch {
            if cancellable.isCancelled { throw CancellationError() }
            throw error
        }
    }

    func cancel() {
        cancellable.cancel()
    }
}
