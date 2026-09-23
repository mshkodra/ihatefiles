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

    func cancel() {
        lock.lock()
        cancelledFlag = true
        let runningProcess = process
        lock.unlock()
        runningProcess?.terminate()
    }

    var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelledFlag
    }
}
