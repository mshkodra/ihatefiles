import Foundation

/// App-target equivalent of the test target's FakeRunner — simulates progress over a
/// handful of ticks so the Queue/ProgressStrip UI has synthetic jobs to react to.
/// Debug-only: wired up from QueueView's "Enqueue Sample Jobs" button.
final class FakeJobRunner: JobRunner, @unchecked Sendable {
    enum Outcome {
        case succeed
        case fail
    }

    private let tickCount: Int
    private let tickDelayNanoseconds: UInt64
    private let outcome: Outcome
    private let lock = NSLock()
    private var cancelledFlag = false

    init(tickCount: Int = 8, tickDelayNanoseconds: UInt64 = 400_000_000, outcome: Outcome = .succeed) {
        self.tickCount = tickCount
        self.tickDelayNanoseconds = tickDelayNanoseconds
        self.outcome = outcome
    }

    func run(job: Job, progress: @escaping @Sendable (Double) -> Void) async throws {
        for tick in 1...tickCount {
            if isCancelled { throw CancellationError() }
            try await Task.sleep(nanoseconds: tickDelayNanoseconds)
            if isCancelled { throw CancellationError() }
            progress(Double(tick) / Double(tickCount))
        }
        if outcome == .fail {
            throw FakeJobRunnerError.simulatedFailure
        }
    }

    func cancel() {
        lock.lock()
        cancelledFlag = true
        lock.unlock()
    }

    private var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelledFlag
    }
}

enum FakeJobRunnerError: Error {
    case simulatedFailure
}
