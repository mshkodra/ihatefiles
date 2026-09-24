import Foundation

/// Buckets jobs into the four groups shown in the Queue view, matching the
/// approved UI mockup: In Progress / Needs Attention / Today / Earlier.
/// Pure and SwiftUI-free so the bucketing logic is directly unit-testable.
enum QueueGrouping {
    enum Group: String, CaseIterable {
        case inProgress = "In Progress"
        case needsAttention = "Needs Attention"
        case today = "Today"
        case earlier = "Earlier"
    }

    /// Returns each non-empty group, in mockup order, with jobs sorted
    /// reverse-chronologically (`updatedAt` descending) within the group.
    static func grouped(
        _ jobs: [Job],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [(group: Group, jobs: [Job])] {
        var buckets: [Group: [Job]] = [:]
        for job in jobs {
            buckets[group(for: job, now: now, calendar: calendar), default: []].append(job)
        }
        return Group.allCases.compactMap { group in
            guard let jobsInGroup = buckets[group], !jobsInGroup.isEmpty else { return nil }
            return (group, jobsInGroup.sorted { $0.updatedAt > $1.updatedAt })
        }
    }

    static func group(for job: Job, now: Date = Date(), calendar: Calendar = .current) -> Group {
        switch job.status {
        case .running, .queued:
            return .inProgress
        case .failed, .cancelled:
            return .needsAttention
        case .done:
            return calendar.isDate(job.updatedAt, inSameDayAs: now) ? .today : .earlier
        }
    }
}
