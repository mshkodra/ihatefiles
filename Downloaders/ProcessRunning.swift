import Foundation

/// Spawns a subprocess and streams its stdout line-by-line. Shared by every
/// Downloaders/Converters runner that shells out to a bundled binary
/// (yt-dlp, ffmpeg, ...). Not itself cancellable — callers that need to
/// terminate an in-flight process early should retain the `Process` via
/// `onLaunch` and call `.terminate()` on it from their own `cancel()`.
enum ProcessRunning {
    struct ProcessError: LocalizedError {
        let exitCode: Int32
        let stderrOutput: String

        var errorDescription: String? {
            let trimmed = stderrOutput.trimmingCharacters(in: .whitespacesAndNewlines)
            return "Process exited with code \(exitCode)" + (trimmed.isEmpty ? "" : ": \(trimmed)")
        }
    }

    /// Runs `executableURL` with `arguments`, invoking `onStdoutLine` for each
    /// newline-terminated line of stdout as it arrives, and `onLaunch` (if
    /// provided) with the live `Process` right after it starts. Throws
    /// `ProcessError` (with captured stderr) on a non-zero exit.
    static func run(
        executableURL: URL,
        arguments: [String],
        onLaunch: (@Sendable (Process) -> Void)? = nil,
        onStdoutLine: @escaping @Sendable (String) -> Void
    ) async throws {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        let lineBuffer = LineBuffer(onLine: onStdoutLine)
        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty {
                handle.readabilityHandler = nil
            } else {
                lineBuffer.append(data)
            }
        }

        let stderrCollector = StderrCollector()
        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty {
                handle.readabilityHandler = nil
            } else {
                stderrCollector.append(data)
            }
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            process.terminationHandler = { proc in
                stdoutPipe.fileHandleForReading.readabilityHandler = nil
                stderrPipe.fileHandleForReading.readabilityHandler = nil
                lineBuffer.flushRemainder()
                if proc.terminationStatus == 0 {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: ProcessError(
                        exitCode: proc.terminationStatus,
                        stderrOutput: stderrCollector.text
                    ))
                }
            }
            do {
                try process.run()
                onLaunch?(process)
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}

/// Thread-safe accumulator that splits incoming stdout bytes on newlines and
/// forwards each complete line, buffering any trailing partial line until
/// `flushRemainder` is called at process exit.
private final class LineBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var pending = Data()
    private let onLine: @Sendable (String) -> Void

    init(onLine: @escaping @Sendable (String) -> Void) {
        self.onLine = onLine
    }

    func append(_ data: Data) {
        lock.lock()
        pending.append(data)
        var lines: [String] = []
        while let newlineIndex = pending.firstIndex(of: 0x0A) {
            let lineData = pending.subdata(in: pending.startIndex..<newlineIndex)
            pending.removeSubrange(pending.startIndex...newlineIndex)
            if let line = String(data: lineData, encoding: .utf8) {
                lines.append(line)
            }
        }
        lock.unlock()
        for line in lines { onLine(line) }
    }

    func flushRemainder() {
        lock.lock()
        let remainder = pending
        pending.removeAll()
        lock.unlock()
        if !remainder.isEmpty, let line = String(data: remainder, encoding: .utf8), !line.isEmpty {
            onLine(line)
        }
    }
}

private final class StderrCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()

    func append(_ chunk: Data) {
        lock.lock()
        data.append(chunk)
        lock.unlock()
    }

    var text: String {
        lock.lock()
        defer { lock.unlock() }
        return String(data: data, encoding: .utf8) ?? ""
    }
}
