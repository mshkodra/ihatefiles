import Foundation

/// Downloads a Twitter/X video via the bundled yt-dlp binary, either the
/// auto-selected best format (`formatId == nil`) or an explicit format the
/// user picked from `TwitterProbeRunner`'s results — mirroring
/// twitter_download.py's "best" vs. literal `format_id` selector. Progress
/// parses the same `[download] NN.N%` lines every yt-dlp download emits.
final class TwitterDownloadRunner: JobRunner, @unchecked Sendable {
    private let url: String
    private let formatId: String?
    private let outputDirectory: URL
    private let cancellable = CancellableProcess()

    init(url: String, formatId: String?, outputDirectory: URL? = nil) {
        self.url = url
        self.formatId = formatId
        self.outputDirectory = outputDirectory
            ?? FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
    }

    func run(job: Job, progress: @escaping @Sendable (Double) -> Void) async throws {
        if cancellable.isCancelled { throw CancellationError() }

        let ytDlpURL = try BinaryLocator.ytDlpURL
        let outputTemplate = outputDirectory.appendingPathComponent("%(uploader)s - %(id)s.%(ext)s").path
        let arguments = [
            url,
            "-f", formatId ?? "best",
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
                onStdoutLine: { line in
                    if let value = YtDlpProgressParser.parseProgress(from: line) {
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
