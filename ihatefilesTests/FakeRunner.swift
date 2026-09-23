import Foundation
@testable import ihatefiles

/// Simulates progress over a handful of short ticks, for exercising JobManager
/// without any real yt-dlp/ffmpeg dependency.
final class FakeRunner: JobRunner, @unchecked Sendable {
    enum Outcome {
        case succeed
        case fail
    }

    private let tickCount: Int
    private let tickDelayNanoseconds: UInt64
    private let outcome: Outcome
    private let lock = NSLock()
    private var cancelledFlag = false

    init(tickCount: Int = 4, tickDelayNanoseconds: UInt64 = 5_000_000, outcome: Outcome = .succeed) {
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
            throw FakeRunnerError.simulatedFailure
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

enum FakeRunnerError: Error {
    case simulatedFailure
}
