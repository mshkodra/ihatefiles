import SwiftUI

/// Grouped queue list (In Progress / Needs Attention / Today / Earlier) matching
/// the approved UI mockup: https://claude.ai/artifact/VaBwtnhGdWYxGps49FPSpH
struct QueueView: View {
    @Environment(JobManager.self) private var jobManager

    private var groups: [(group: QueueGrouping.Group, jobs: [Job])] {
        QueueGrouping.grouped(jobManager.jobs)
    }

    var body: some View {
        Group {
            if groups.isEmpty {
                ContentUnavailableView(
                    "No jobs yet",
                    systemImage: "tray",
                    description: Text("Downloads and conversions you start will show up here.")
                )
            } else {
                List {
                    ForEach(groups, id: \.group) { entry in
                        Section {
                            ForEach(entry.jobs) { job in
                                QueueRow(job: job)
                            }
                        } header: {
                            GroupHeader(group: entry.group, count: entry.jobs.count)
                        }
                    }
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

/// Section header reading In Progress / Needs Attention as more prominent
/// than the historical Today / Earlier groups, per the mockup's intent.
private struct GroupHeader: View {
    let group: QueueGrouping.Group
    let count: Int

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: symbolName)
                .foregroundStyle(color)
            Text(group.rawValue)
            Spacer()
            Text("\(count)")
                .foregroundStyle(.secondary)
        }
    }

    private var symbolName: String {
        switch group {
        case .inProgress: return "arrow.triangle.2.circlepath"
        case .needsAttention: return "exclamationmark.triangle.fill"
        case .today: return "checkmark.circle"
        case .earlier: return "clock"
        }
    }

    private var color: Color {
        switch group {
        case .inProgress: return .accentColor
        case .needsAttention: return .red
        case .today, .earlier: return .secondary
        }
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
