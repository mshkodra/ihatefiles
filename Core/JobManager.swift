import Foundation
import Observation

/// Owns the app's job list. Downloads are subject to `downloadConcurrencyLimit`
/// (extra ones sit `.queued` until a slot frees); conversions always start immediately.
@MainActor
@Observable
final class JobManager {
    private(set) var jobs: [Job] = []
    /// Changing this (e.g. from Settings) immediately starts any newly
    /// affordable queued downloads — not just on the next unrelated
    /// enqueue/finish event — so a live cap increase takes effect right away.
    var downloadConcurrencyLimit: Int {
        didSet { startNextQueuedDownloadIfSlotAvailable() }
    }

    private var runners: [UUID: JobRunner] = [:]
    private var tasks: [UUID: Task<Void, Never>] = [:]

    init(downloadConcurrencyLimit: Int = 2) {
        self.downloadConcurrencyLimit = downloadConcurrencyLimit
    }

    @discardableResult
    func enqueue(kind: JobKind, input: String, runner: JobRunner, parentId: UUID? = nil) -> UUID {
        let job = Job(kind: kind, input: input, parentId: parentId)
        jobs.append(job)
        runners[job.id] = runner

        if kind.isDownload {
            startNextQueuedDownloadIfSlotAvailable()
        } else {
            start(jobId: job.id)
        }
        return job.id
    }

    func cancel(jobId: UUID) {
        guard let index = jobs.firstIndex(where: { $0.id == jobId }) else { return }
        let status = jobs[index].status
        guard status == .queued || status == .running else { return }

        let wasRunningDownload = status == .running && jobs[index].kind.isDownload

        if status == .running {
            runners[jobId]?.cancel()
            tasks[jobId]?.cancel()
        }

        jobs[index].status = .cancelled
        jobs[index].updatedAt = Date()
        runners[jobId] = nil
        tasks[jobId] = nil

        if wasRunningDownload {
            startNextQueuedDownloadIfSlotAvailable()
        }
    }

    // MARK: - Scheduling

    private func runningDownloadCount() -> Int {
        jobs.filter { $0.kind.isDownload && $0.status == .running }.count
    }

    /// Starts as many queued downloads as there are free slots for — usually
    /// just one (a single job finished/cancelled), but a live cap increase
    /// from Settings can free several slots at once, so this fills all of
    /// them rather than only the first.
    private func startNextQueuedDownloadIfSlotAvailable() {
        while runningDownloadCount() < downloadConcurrencyLimit,
              let next = jobs.first(where: { $0.kind.isDownload && $0.status == .queued }) {
            start(jobId: next.id)
        }
    }

    private func start(jobId: UUID) {
        guard let runner = runners[jobId],
              let index = jobs.firstIndex(where: { $0.id == jobId }) else { return }

        jobs[index].status = .running
        jobs[index].updatedAt = Date()
        let snapshot = jobs[index]

        tasks[jobId] = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await runner.run(job: snapshot) { value in
                    Task { @MainActor in
                        self.applyProgress(jobId: jobId, value: value)
                    }
                }
                self.finish(jobId: jobId, status: .done)
            } catch is CancellationError {
                self.finish(jobId: jobId, status: .cancelled)
            } catch {
                self.finish(jobId: jobId, status: .failed)
            }
        }
    }

    private func applyProgress(jobId: UUID, value: Double) {
        guard let index = jobs.firstIndex(where: { $0.id == jobId }), jobs[index].status == .running else { return }
        jobs[index].progress = value
        jobs[index].updatedAt = Date()
    }

    private func finish(jobId: UUID, status: JobStatus) {
        guard let index = jobs.firstIndex(where: { $0.id == jobId }), jobs[index].status == .running else { return }

        let wasDownload = jobs[index].kind.isDownload
        jobs[index].status = status
        jobs[index].updatedAt = Date()
        if status == .done { jobs[index].progress = 1 }

        runners[jobId] = nil
        tasks[jobId] = nil

        if wasDownload {
            startNextQueuedDownloadIfSlotAvailable()
        }
    }
}
