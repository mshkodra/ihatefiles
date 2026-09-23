import Foundation

/// Downloads a single YouTube video as MP4 via the bundled yt-dlp binary,
/// reporting live progress parsed from its `--newline`-mode stdout. Output
/// defaults to the user's Downloads folder; a configurable destination is
/// added in a later phase (Settings).
final class YouTubeVideoRunner: JobRunner, @unchecked Sendable {
    private let url: String
    private let outputDirectory: URL

    private let lock = NSLock()
    private var process: Process?
    private var cancelledFlag = false

    init(url: String, outputDirectory: URL? = nil) {
        self.url = url
        self.outputDirectory = outputDirectory
            ?? FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
    }

    func run(job: Job, progress: @escaping @Sendable (Double) -> Void) async throws {
        if isCancelled { throw CancellationError() }

        let ytDlpURL = try BinaryLocator.ytDlpURL
        let outputTemplate = outputDirectory.appendingPathComponent("%(title)s.%(ext)s").path
        let arguments = [
            url,
            "-f", "bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best",
            "--merge-output-format", "mp4",
            "-o", outputTemplate,
            "--newline",
        ]

        do {
            try await ProcessRunning.run(
                executableURL: ytDlpURL,
                arguments: arguments,
                onLaunch: { [weak self] process in
                    self?.storeProcess(process)
                },
                onStdoutLine: { line in
                    if let value = YtDlpProgressParser.parseProgress(from: line) {
                        progress(value)
                    }
                }
            )
        } catch {
            if isCancelled { throw CancellationError() }
            throw error
        }
    }

    func cancel() {
        lock.lock()
        cancelledFlag = true
        let runningProcess = process
        lock.unlock()
        runningProcess?.terminate()
    }

    private func storeProcess(_ process: Process) {
        lock.lock()
        self.process = process
        lock.unlock()
    }

    private var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelledFlag
    }
}
