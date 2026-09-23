import SwiftUI

/// Persistent live summary docked to the bottom of the content pane, visible across
/// every section so the user can see queue activity while working elsewhere.
struct ProgressStrip: View {
    let jobs: [Job]

    private var runningCount: Int { jobs.filter { $0.status == .running }.count }
    private var queuedCount: Int { jobs.filter { $0.status == .queued }.count }
    private var doneCount: Int { jobs.filter { $0.status == .done }.count }

    var body: some View {
        HStack(spacing: 16) {
            summaryItem(count: runningCount, label: "running", color: .accentColor)
            summaryItem(count: queuedCount, label: "queued", color: .gray)
            summaryItem(count: doneCount, label: "done", color: .green)
            Spacer()
        }
        .font(.subheadline)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
        .overlay(alignment: .top) {
            Divider()
        }
    }

    private func summaryItem(count: Int, label: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Text("\(count)")
                .fontWeight(.semibold)
                .foregroundStyle(color)
            Text(label)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    ProgressStrip(jobs: [
        Job(kind: .youtubeVideo, input: "a", status: .running, progress: 0.4),
        Job(kind: .videoConvert, input: "b", status: .queued),
        Job(kind: .imageConvert, input: "c", status: .done, progress: 1),
    ])
}
