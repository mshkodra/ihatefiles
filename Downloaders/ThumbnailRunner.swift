import Foundation

/// Fetches just a YouTube video's thumbnail (no video/audio) via the bundled
/// yt-dlp binary, converting it to jpg. yt-dlp reports no percentage for a
/// single-file thumbnail fetch, so this runner reports no interim progress —
/// JobManager marks the job 100% complete when it finishes successfully.
final class ThumbnailRunner: JobRunner, @unchecked Sendable {
    private let url: String
    private let outputDirectory: URL
    private let cancellable = CancellableProcess()

    init(url: String, outputDirectory: URL? = nil) {
        self.url = url
        self.outputDirectory = outputDirectory
            ?? FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
    }

    func run(job: Job, progress: @escaping @Sendable (Double) -> Void) async throws {
        if cancellable.isCancelled { throw CancellationError() }

        let ytDlpURL = try BinaryLocator.ytDlpURL
        let outputTemplate = outputDirectory.appendingPathComponent("%(title)s.%(ext)s").path
        let arguments = [
            url,
            "--write-thumbnail",
            "--skip-download",
            "--convert-thumbnails", "jpg",
            "-o", outputTemplate,
            "--newline",
        ]

        do {
            try await ProcessRunning.run(
                executableURL: ytDlpURL,
                arguments: arguments,
                onLaunch: { [cancellable] process in
                    cancellable.store(process)
                },
                onStdoutLine: { _ in }
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
