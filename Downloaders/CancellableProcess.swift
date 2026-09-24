import Foundation

/// Thread-safe holder for an in-flight `Process` plus a cancellation flag.
/// Shared by runners that shell out to a bundled binary and need to
/// terminate it early from `JobRunner.cancel()`.
final class CancellableProcess: @unchecked Sendable {
    private let lock = NSLock()
    private var process: Process?
    private var cancelledFlag = false

    func store(_ process: Process) {
        lock.lock()
        self.process = process
        lock.unlock()
    }

    /// Sends SIGTERM immediately, then escalates to SIGKILL after a short
    /// grace period if the process is still alive. Some bundled binaries
    /// (notably yt-dlp's PyInstaller build, which can spend its first ~11s
    /// in bootstrap before its own signal handling is installed) don't
    /// reliably exit on SIGTERM alone — without this fallback, a cancel
    /// request could leave the process hung and the job stuck mid-cancel.
    func cancel() {
        lock.lock()
        cancelledFlag = true
        let runningProcess = process
        lock.unlock()
        guard let runningProcess, runningProcess.isRunning else { return }

        runningProcess.terminate()
        DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
            if runningProcess.isRunning {
                kill(runningProcess.processIdentifier, SIGKILL)
            }
        }
    }

    var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelledFlag
    }
}
