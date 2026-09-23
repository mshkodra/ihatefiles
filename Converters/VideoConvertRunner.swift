import Foundation

/// Converts a video to H.264/AAC MP4 via the bundled ffmpeg, reporting real
/// progress parsed from `-progress pipe:1` against the input's probed
/// duration. A conversion (JobKind.videoConvert), not a download — JobManager
/// runs it immediately, uncapped, regardless of how many downloads are
/// queued behind the concurrency limit.
final class VideoConvertRunner: JobRunner, @unchecked Sendable {
    private let inputURL: URL
    private let outputURL: URL
    private let cancellable = CancellableProcess()

    init(inputURL: URL, outputURL: URL) {
        self.inputURL = inputURL
        self.outputURL = outputURL
    }

    func run(job: Job, progress: @escaping @Sendable (Double) -> Void) async throws {
        if cancellable.isCancelled { throw CancellationError() }

        let ffmpegURL = try BinaryLocator.ffmpegURL
        let duration = try await VideoDurationProbe.duration(of: inputURL)
        if cancellable.isCancelled { throw CancellationError() }

        let parser = FfmpegProgressParser(totalDuration: duration)

        do {
            try await ProcessRunning.run(
                executableURL: ffmpegURL,
                arguments: [
                    "-i", inputURL.path,
                    "-c:v", "libx264",
                    "-preset", "medium",
                    "-crf", "23",
                    "-c:a", "aac",
                    "-b:a", "128k",
                    "-progress", "pipe:1",
                    "-y", outputURL.path,
                ],
                onLaunch: { [cancellable] process in
                    cancellable.store(process)
                },
                onStdoutLine: { line in
                    if let value = parser.ingest(line: line) {
                        progress(value)
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
