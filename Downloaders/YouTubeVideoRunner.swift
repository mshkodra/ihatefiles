import Foundation

/// What to download a YouTube video as.
enum DownloadFormat {
    case mp4
    case mp3

    /// yt-dlp arguments for this format, matching youtube_download.py's
    /// original settings (mp4: prefer native mp4/m4a streams, merge to mp4;
    /// mp3: FFmpegExtractAudio postprocessor at 192kbps).
    fileprivate func arguments(url: String, outputTemplate: String) -> [String] {
        switch self {
        case .mp4:
            return [
                url,
                "-f", "bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best",
                "--merge-output-format", "mp4",
                "-o", outputTemplate,
                "--newline",
            ]
        case .mp3:
            return [
                url,
                "-x",
                "--audio-format", "mp3",
                "--audio-quality", "192K",
                "-o", outputTemplate,
                "--newline",
            ]
        }
    }
}

/// Downloads a single YouTube video as MP4 or MP3 via the bundled yt-dlp
/// binary, reporting live progress parsed from its `--newline`-mode stdout.
/// Output defaults to the user's Downloads folder; a configurable
/// destination is added in a later phase (Settings).
final class YouTubeVideoRunner: JobRunner, @unchecked Sendable {
    private let url: String
    private let format: DownloadFormat
    private let outputDirectory: URL
    private let cancellable = CancellableProcess()

    init(url: String, format: DownloadFormat = .mp4, outputDirectory: URL? = nil) {
        self.url = url
        self.format = format
        self.outputDirectory = outputDirectory
            ?? FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
    }

    func run(job: Job, progress: @escaping @Sendable (Double) -> Void) async throws {
        if cancellable.isCancelled { throw CancellationError() }

        let ytDlpURL = try BinaryLocator.ytDlpURL
        let outputTemplate = outputDirectory.appendingPathComponent("%(title)s.%(ext)s").path
        let arguments = format.arguments(url: url, outputTemplate: outputTemplate)

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
