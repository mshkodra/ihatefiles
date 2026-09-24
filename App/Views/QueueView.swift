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
        #if DEBUG
        .toolbar {
            ToolbarItem {
                Button("Enqueue Sample Jobs", action: enqueueSampleJobs)
            }
        }
        #endif
    }

    #if DEBUG
    /// Populates the queue with a mix of download/conversion kinds and
    /// simulated progress, for exercising the live queue UI (concurrency
    /// capping, grouping, status colors) without running real tools.
    private func enqueueSampleJobs() {
        let downloads: [JobKind] = [.youtubeVideo, .youtubePlaylist, .twitter, .genericURL, .youtubeVideo]
        let conversions: [JobKind] = [.videoConvert, .imageConvert, .pdfMerge, .videoSplit, .videoConcat]

        for (index, kind) in downloads.enumerated() {
            jobManager.enqueue(kind: kind, input: "sample-\(kind.rawValue)-\(index)", runner: FakeJobRunner())
        }
        for (index, kind) in conversions.enumerated() {
            jobManager.enqueue(kind: kind, input: "sample-\(kind.rawValue)-\(index)", runner: FakeJobRunner())
        }
    }
    #endif
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
