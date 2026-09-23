import SwiftUI

/// Stand-in for Downloader/Video/Image/PDF until their real per-tool views land in
/// later phases. Includes a debug control to exercise the live queue/progress UI.
struct PlaceholderToolView: View {
    @Environment(JobManager.self) private var jobManager
    let section: AppSection

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: section.symbolName)
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("\(section.title) tools land in a later phase")
                .foregroundStyle(.secondary)

            #if DEBUG
            Button("Enqueue sample jobs") {
                enqueueSampleJobs()
            }
            .buttonStyle(.bordered)
            #endif
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(section.title)
    }

    #if DEBUG
    private func enqueueSampleJobs() {
        let downloads: [JobKind] = [.youtubeVideo, .youtubePlaylist, .twitter, .genericURL, .youtubeVideo]
        let conversions: [JobKind] = [.videoConvert, .imageConvert, .pdfMerge, .videoSplit, .videoConcat]

        for (index, kind) in downloads.enumerated() {
            jobManager.enqueue(
                kind: kind,
                input: "sample-\(kind.rawValue)-\(index)",
                runner: FakeJobRunner()
            )
        }
        for (index, kind) in conversions.enumerated() {
            jobManager.enqueue(
                kind: kind,
                input: "sample-\(kind.rawValue)-\(index)",
                runner: FakeJobRunner()
            )
        }
    }
    #endif
}

#Preview {
    PlaceholderToolView(section: .downloader)
        .environment(JobManager())
}
