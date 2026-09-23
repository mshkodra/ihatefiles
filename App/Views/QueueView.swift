import SwiftUI

/// Flat reverse-chronological job list. Grouped sections (In Progress / Needs Attention /
/// Today / Earlier) are deferred to a later phase — this phase just proves the live binding.
struct QueueView: View {
    @Environment(JobManager.self) private var jobManager

    private var sortedJobs: [Job] {
        jobManager.jobs.sorted { $0.updatedAt > $1.updatedAt }
    }

    var body: some View {
        Group {
            if sortedJobs.isEmpty {
                ContentUnavailableView(
                    "No jobs yet",
                    systemImage: "tray",
                    description: Text("Downloads and conversions you start will show up here.")
                )
            } else {
                List(sortedJobs) { job in
                    QueueRow(job: job)
                }
            }
        }
        .navigationTitle("Queue")
    }
}

private struct QueueRow: View {
    let job: Job

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(job.input)
                    .lineLimit(1)
                Text(job.kind.rawValue + (job.parentId != nil ? " · playlist" : ""))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if job.status == .running {
                ProgressView(value: job.progress)
                    .frame(width: 80)
            }
            StatusPill(status: job.status)
        }
        .padding(.vertical, 2)
    }
}
