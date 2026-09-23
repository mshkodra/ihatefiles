import Foundation

/// Downloads from any yt-dlp-supported site that isn't YouTube or Twitter/X
/// (Vimeo, SoundCloud, Instagram, ...) via yt-dlp's own default best-format
/// selection — no source-specific `-f` selector, unlike the YouTube/Twitter
/// runners. Progress parses the same `[download] NN.N%` lines every yt-dlp
/// download emits.
final class GenericURLRunner: JobRunner, @unchecked Sendable {
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
            "-f", "best",
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
