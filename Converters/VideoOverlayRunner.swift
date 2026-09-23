import Foundation

/// Picture-in-picture overlay: shrinks `webcamURL` to 20% of `screenURL`'s
/// width (preserving the webcam's own aspect ratio) and composites it over
/// the top-right corner with a 20px margin. This is the real, shipped
/// behavior of the original `embed_a_onto_b.py` — that script's comments
/// said "top-left" but its actual math placed the overlay top-right; this
/// runner standardizes on top-right (the real behavior) rather than the
/// stale comment. Audio comes only from `screenURL`, matching the original
/// (filter_complex here only maps video; default stream mapping takes audio
/// from the first input that has it).
final class VideoOverlayRunner: JobRunner, @unchecked Sendable {
    private let screenURL: URL
    private let webcamURL: URL
    private let outputURL: URL
    private let cancellable = CancellableProcess()

    init(screenURL: URL, webcamURL: URL, outputURL: URL) {
        self.screenURL = screenURL
        self.webcamURL = webcamURL
        self.outputURL = outputURL
    }

    /// Overlay size (20% of the screen recording's width, webcam's own
    /// aspect ratio preserved) and top-right position with a 20px margin.
    static func geometry(
        screenWidth: Int, screenHeight: Int,
        webcamWidth: Int, webcamHeight: Int
    ) -> (overlayWidth: Int, overlayHeight: Int, x: Int, y: Int) {
        let overlayWidth = Int(Double(screenWidth) * 0.20)
        let overlayHeight = Int(Double(overlayWidth) * (Double(webcamHeight) / Double(webcamWidth)))
        let x = screenWidth - overlayWidth - 20
        let y = 20
        return (overlayWidth, overlayHeight, x, y)
    }

    func run(job: Job, progress: @escaping @Sendable (Double) -> Void) async throws {
        if cancellable.isCancelled { throw CancellationError() }

        let ffmpegURL = try BinaryLocator.ffmpegURL
        let screenDuration = try await VideoDurationProbe.duration(of: screenURL)
        let screenDimensions = try await VideoDimensionsProbe.dimensions(of: screenURL)
        let webcamDimensions = try await VideoDimensionsProbe.dimensions(of: webcamURL)
        if cancellable.isCancelled { throw CancellationError() }

        let geometry = Self.geometry(
            screenWidth: screenDimensions.width, screenHeight: screenDimensions.height,
            webcamWidth: webcamDimensions.width, webcamHeight: webcamDimensions.height
        )
        let filterComplex = "[0:v]fps=30[base];[1:v]fps=30,scale=\(geometry.overlayWidth):\(geometry.overlayHeight)[overlay];[base][overlay]overlay=\(geometry.x):\(geometry.y)"

        let parser = FfmpegProgressParser(totalDuration: screenDuration)
        do {
            try await ProcessRunning.run(
                executableURL: ffmpegURL,
                arguments: [
                    "-i", screenURL.path,
                    "-i", webcamURL.path,
                    "-filter_complex", filterComplex,
                    "-c:v", "libx264",
                    "-preset", "medium",
                    "-crf", "18",
                    "-pix_fmt", "yuv420p",
                    "-c:a", "aac",
                    "-b:a", "192k",
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
