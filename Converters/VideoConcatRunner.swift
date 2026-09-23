import Foundation

/// Concatenates 2+ videos in order, via two strategies mirroring the
/// original `concat_videos_fast.py` (stream-copy, needs matching
/// codecs/resolution/fps) and `concat_videos.py` (re-encode, tolerates
/// mismatches). Both shell to the bundled ffmpeg rather than reimplementing
/// muxing via AVFoundation.
final class VideoConcatRunner: JobRunner, @unchecked Sendable {
    enum Mode {
        case fast // ffmpeg concat demuxer, -c copy
        case compatible // -filter_complex concat, re-encodes
    }

    struct ValidationError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    private let inputURLs: [URL]
    private let outputURL: URL
    private let mode: Mode
    private let cancellable = CancellableProcess()

    init(inputURLs: [URL], outputURL: URL, mode: Mode) {
        self.inputURLs = inputURLs
        self.outputURL = outputURL
        self.mode = mode
    }

    /// Concat demuxer file-list lines, e.g. `file '/a/b.mp4'`. Single quotes
    /// in a path are escaped per ffmpeg's documented convention (`'\''`).
    static func buildFileList(paths: [String]) -> String {
        paths.map { path in
            "file '\(path.replacingOccurrences(of: "'", with: "'\\''"))'"
        }.joined(separator: "\n") + "\n"
    }

    /// A `-filter_complex concat` graph for N inputs, mapping each input's
    /// first video and audio stream in order.
    static func buildFilterComplex(inputCount: Int) -> String {
        let streamRefs = (0..<inputCount).map { "[\($0):v:0][\($0):a:0]" }.joined()
        return "\(streamRefs)concat=n=\(inputCount):v=1:a=1[outv][outa]"
    }

    func run(job: Job, progress: @escaping @Sendable (Double) -> Void) async throws {
        guard inputURLs.count >= 2 else {
            throw ValidationError(message: "Concatenation needs at least 2 input videos.")
        }
        if cancellable.isCancelled { throw CancellationError() }

        let ffmpegURL = try BinaryLocator.ffmpegURL
        var totalDuration: TimeInterval = 0
        for url in inputURLs {
            totalDuration += try await VideoDurationProbe.duration(of: url)
        }
        if cancellable.isCancelled { throw CancellationError() }

        switch mode {
        case .fast:
            try await runFast(ffmpegURL: ffmpegURL, totalDuration: totalDuration, progress: progress)
        case .compatible:
            try await runCompatible(ffmpegURL: ffmpegURL, totalDuration: totalDuration, progress: progress)
        }
    }

    private func runFast(ffmpegURL: URL, totalDuration: TimeInterval, progress: @escaping @Sendable (Double) -> Void) async throws {
        let fileListURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ihatefiles-concat-\(UUID().uuidString)")
            .appendingPathExtension("txt")
        let fileList = Self.buildFileList(paths: inputURLs.map(\.path))
        try fileList.write(to: fileListURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: fileListURL) }

        let parser = FfmpegProgressParser(totalDuration: totalDuration)
        try await runFfmpeg(
            ffmpegURL: ffmpegURL,
            arguments: ["-f", "concat", "-safe", "0", "-i", fileListURL.path, "-c", "copy", "-progress", "pipe:1", "-y", outputURL.path],
            parser: parser,
            progress: progress
        )
    }

    private func runCompatible(ffmpegURL: URL, totalDuration: TimeInterval, progress: @escaping @Sendable (Double) -> Void) async throws {
        var arguments: [String] = []
        for url in inputURLs { arguments += ["-i", url.path] }
        arguments += [
            "-filter_complex", Self.buildFilterComplex(inputCount: inputURLs.count),
            "-map", "[outv]", "-map", "[outa]",
            "-c:v", "libx264", "-preset", "medium", "-crf", "23",
            "-c:a", "aac", "-b:a", "128k",
            "-progress", "pipe:1", "-y", outputURL.path,
        ]

        let parser = FfmpegProgressParser(totalDuration: totalDuration)
        try await runFfmpeg(ffmpegURL: ffmpegURL, arguments: arguments, parser: parser, progress: progress)
    }

    private func runFfmpeg(
        ffmpegURL: URL,
        arguments: [String],
        parser: FfmpegProgressParser,
        progress: @escaping @Sendable (Double) -> Void
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
