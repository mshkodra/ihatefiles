import XCTest
@testable import ihatefiles

@MainActor
final class JobManagerTests: XCTestCase {

    func testDownloadsRespectConcurrencyCap() async throws {
        let manager = JobManager(downloadConcurrencyLimit: 2)
        for _ in 0..<5 {
            manager.enqueue(
                kind: .youtubeVideo, input: "url",
                runner: FakeRunner(tickCount: 50, tickDelayNanoseconds: 20_000_000)
            )
        }

        try await waitUntil(timeout: 2) {
            manager.jobs.filter { $0.status == .running }.count == 2
        }

        XCTAssertEqual(manager.jobs.filter { $0.status == .running }.count, 2)
        XCTAssertEqual(manager.jobs.filter { $0.status == .queued }.count, 3)
    }

    func testQueuedDownloadStartsWhenSlotFrees() async throws {
        let manager = JobManager(downloadConcurrencyLimit: 1)
        let firstId = manager.enqueue(
            kind: .youtubeVideo, input: "a",
            runner: FakeRunner(tickCount: 2, tickDelayNanoseconds: 10_000_000)
        )
        let secondId = manager.enqueue(
            kind: .youtubeVideo, input: "b",
            runner: FakeRunner(tickCount: 2, tickDelayNanoseconds: 10_000_000)
        )

        XCTAssertEqual(manager.jobs.first(where: { $0.id == secondId })?.status, .queued)

        try await waitUntil(timeout: 2) {
            manager.jobs.first(where: { $0.id == firstId })?.status == .done
        }
        try await waitUntil(timeout: 2) {
            manager.jobs.first(where: { $0.id == secondId })?.status == .running
                || manager.jobs.first(where: { $0.id == secondId })?.status == .done
        }

        let secondStatus = manager.jobs.first(where: { $0.id == secondId })?.status
        XCTAssertTrue(secondStatus == .running || secondStatus == .done)
    }

    func testConversionsIgnoreConcurrencyCap() async throws {
        let manager = JobManager(downloadConcurrencyLimit: 2)
        for _ in 0..<5 {
            manager.enqueue(
                kind: .videoConvert, input: "file",
                runner: FakeRunner(tickCount: 50, tickDelayNanoseconds: 20_000_000)
            )
        }

        try await waitUntil(timeout: 2) {
            manager.jobs.filter { $0.status == .running }.count == 5
        }

        XCTAssertEqual(manager.jobs.filter { $0.status == .running }.count, 5)
    }

    func testCancellingRunningDownloadFreesSlot() async throws {
        let manager = JobManager(downloadConcurrencyLimit: 1)
        let firstId = manager.enqueue(
            kind: .youtubeVideo, input: "a",
            runner: FakeRunner(tickCount: 200, tickDelayNanoseconds: 20_000_000)
        )
        let secondId = manager.enqueue(
            kind: .youtubeVideo, input: "b",
            runner: FakeRunner(tickCount: 2, tickDelayNanoseconds: 10_000_000)
        )

        try await waitUntil(timeout: 2) {
            manager.jobs.first(where: { $0.id == firstId })?.status == .running
        }
        XCTAssertEqual(manager.jobs.first(where: { $0.id == secondId })?.status, .queued)

        manager.cancel(jobId: firstId)
        XCTAssertEqual(manager.jobs.first(where: { $0.id == firstId })?.status, .cancelled)

        try await waitUntil(timeout: 2) {
            manager.jobs.first(where: { $0.id == secondId })?.status == .running
        }
        XCTAssertEqual(manager.jobs.first(where: { $0.id == secondId })?.status, .running)
    }

    func testFailingJobDoesNotBlockQueue() async throws {
        let manager = JobManager(downloadConcurrencyLimit: 1)
        let failingId = manager.enqueue(
            kind: .youtubeVideo, input: "bad",
            runner: FakeRunner(tickCount: 2, tickDelayNanoseconds: 10_000_000, outcome: .fail)
        )
        let secondId = manager.enqueue(
            kind: .youtubeVideo, input: "good",
            runner: FakeRunner(tickCount: 2, tickDelayNanoseconds: 10_000_000)
        )

        try await waitUntil(timeout: 2) {
            manager.jobs.first(where: { $0.id == failingId })?.status == .failed
        }
        try await waitUntil(timeout: 2) {
            manager.jobs.first(where: { $0.id == secondId })?.status == .done
        }

        XCTAssertEqual(manager.jobs.first(where: { $0.id == failingId })?.status, .failed)
        XCTAssertEqual(manager.jobs.first(where: { $0.id == secondId })?.status, .done)
    }

    func testEnqueueStoresParentId() async throws {
        let manager = JobManager(downloadConcurrencyLimit: 2)
        let parentId = UUID()
        let childId = manager.enqueue(
            kind: .youtubeVideo, input: "child",
            runner: FakeRunner(tickCount: 2, tickDelayNanoseconds: 10_000_000),
            parentId: parentId
        )

        XCTAssertEqual(manager.jobs.first(where: { $0.id == childId })?.parentId, parentId)
    }

    /// Simulates what SettingsView's concurrency stepper does at runtime:
    /// raising `downloadConcurrencyLimit` on an already-running manager
    /// should immediately promote queued downloads into newly-freed slots,
    /// not wait for an unrelated enqueue/finish event to notice.
    func testRaisingConcurrencyLimitLiveStartsQueuedDownloads() async throws {
        let manager = JobManager(downloadConcurrencyLimit: 1)
        for _ in 0..<3 {
            manager.enqueue(
                kind: .youtubeVideo, input: "url",
                runner: FakeRunner(tickCount: 50, tickDelayNanoseconds: 20_000_000)
            )
        }

        try await waitUntil(timeout: 2) {
            manager.jobs.filter { $0.status == .running }.count == 1
        }
        XCTAssertEqual(manager.jobs.filter { $0.status == .queued }.count, 2)

        manager.downloadConcurrencyLimit = 3

        try await waitUntil(timeout: 2) {
            manager.jobs.filter { $0.status == .running }.count == 3
        }
        XCTAssertEqual(manager.jobs.filter { $0.status == .queued }.count, 0)
    }

    // MARK: - Helpers

    private func waitUntil(timeout: TimeInterval, condition: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            if Date() > deadline {
                XCTFail("Timed out waiting for condition")
                return
            }
            try await Task.sleep(nanoseconds: 5_000_000)
        }
    }
}
