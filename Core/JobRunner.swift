import Foundation

protocol JobRunner: Sendable {
    /// Performs the job's work, invoking `progress` with values in 0...1 as it advances.
    /// Throws on failure; returns normally on success. Should return promptly after `cancel()`
    /// is called, typically by checking `Task.isCancelled` or terminating an underlying process.
    func run(job: Job, progress: @escaping @Sendable (Double) -> Void) async throws

    /// Requests early termination of an in-flight `run`. Safe to call even if the job
    /// has already finished.
    func cancel()
}
