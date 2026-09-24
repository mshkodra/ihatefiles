import XCTest
@testable import ihatefiles

final class QueueGroupingTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_700_000_000) // fixed reference instant
    private lazy var calendar = Calendar(identifier: .gregorian)

    private func job(
        kind: JobKind = .youtubeVideo,
        status: JobStatus,
        updatedAt: Date,
        input: String = "job"
    ) -> Job {
        Job(kind: kind, input: input, status: status, updatedAt: updatedAt)
    }

    func testRunningAndQueuedLandInProgress() {
        let jobs = [
            job(status: .running, updatedAt: now),
            job(status: .queued, updatedAt: now),
        ]
        let grouped = QueueGrouping.grouped(jobs, now: now, calendar: calendar)
        XCTAssertEqual(grouped.count, 1)
        XCTAssertEqual(grouped[0].group, .inProgress)
        XCTAssertEqual(grouped[0].jobs.count, 2)
    }

    func testFailedAndCancelledLandInNeedsAttention() {
        let jobs = [
            job(status: .failed, updatedAt: now),
            job(status: .cancelled, updatedAt: now),
        ]
        let grouped = QueueGrouping.grouped(jobs, now: now, calendar: calendar)
        XCTAssertEqual(grouped.count, 1)
        XCTAssertEqual(grouped[0].group, .needsAttention)
        XCTAssertEqual(grouped[0].jobs.count, 2)
    }

    func testDoneTodayLandsInToday() {
        let earlierToday = calendar.date(byAdding: .hour, value: -2, to: now)!
        let jobs = [job(status: .done, updatedAt: earlierToday)]
        let grouped = QueueGrouping.grouped(jobs, now: now, calendar: calendar)
        XCTAssertEqual(grouped.count, 1)
        XCTAssertEqual(grouped[0].group, .today)
    }

    func testDoneYesterdayLandsInEarlier() {
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
        let jobs = [job(status: .done, updatedAt: yesterday)]
        let grouped = QueueGrouping.grouped(jobs, now: now, calendar: calendar)
        XCTAssertEqual(grouped.count, 1)
        XCTAssertEqual(grouped[0].group, .earlier)
    }

    func testDoneLastWeekLandsInEarlier() {
        let lastWeek = calendar.date(byAdding: .day, value: -7, to: now)!
        XCTAssertEqual(
            QueueGrouping.group(for: job(status: .done, updatedAt: lastWeek), now: now, calendar: calendar),
            .earlier
        )
    }

    func testMixedScenarioProducesAllFourGroupsInMockupOrder() {
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
        let jobs = [
            job(status: .running, updatedAt: now),
            job(status: .queued, updatedAt: now),
            job(status: .queued, updatedAt: now),
            job(status: .failed, updatedAt: now),
            job(status: .done, updatedAt: now),
            job(status: .done, updatedAt: yesterday),
        ]
        let grouped = QueueGrouping.grouped(jobs, now: now, calendar: calendar)
        XCTAssertEqual(grouped.map(\.group), [.inProgress, .needsAttention, .today, .earlier])
        XCTAssertEqual(grouped[0].jobs.count, 3) // running + 2 queued
        XCTAssertEqual(grouped[1].jobs.count, 1) // failed
        XCTAssertEqual(grouped[2].jobs.count, 1) // done today
        XCTAssertEqual(grouped[3].jobs.count, 1) // done yesterday
    }

    func testEmptyGroupsAreOmitted() {
        let jobs = [job(status: .running, updatedAt: now)]
        let grouped = QueueGrouping.grouped(jobs, now: now, calendar: calendar)
        XCTAssertEqual(grouped.count, 1)
        XCTAssertFalse(grouped.map(\.group).contains(.needsAttention))
        XCTAssertFalse(grouped.map(\.group).contains(.today))
        XCTAssertFalse(grouped.map(\.group).contains(.earlier))
    }

    func testJobsWithinAGroupAreSortedNewestFirst() {
        let older = calendar.date(byAdding: .minute, value: -10, to: now)!
        let jobs = [
            job(status: .running, updatedAt: older, input: "older"),
            job(status: .running, updatedAt: now, input: "newer"),
        ]
        let grouped = QueueGrouping.grouped(jobs, now: now, calendar: calendar)
        XCTAssertEqual(grouped[0].jobs.map(\.input), ["newer", "older"])
    }

    func testDownloadsAndConversionsInterleaveInInProgressByRecency() {
        let older = calendar.date(byAdding: .minute, value: -5, to: now)!
        let jobs = [
            job(kind: .youtubeVideo, status: .queued, updatedAt: older, input: "download-queued"),
            job(kind: .videoConvert, status: .running, updatedAt: now, input: "conversion-running"),
            job(kind: .imageConvert, status: .running, updatedAt: older, input: "conversion-running-2"),
        ]
        let grouped = QueueGrouping.grouped(jobs, now: now, calendar: calendar)
        XCTAssertEqual(grouped.count, 1)
        XCTAssertEqual(grouped[0].group, .inProgress)
        // Newest first, regardless of download vs. conversion origin.
        XCTAssertEqual(
            grouped[0].jobs.map(\.input),
            ["conversion-running", "download-queued", "conversion-running-2"]
        )
    }
}
