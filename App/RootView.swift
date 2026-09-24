import SwiftUI

struct RootView: View {
    @Environment(JobManager.self) private var jobManager
    @State private var selection: AppSection? = .downloader

    var body: some View {
        NavigationSplitView {
            List(AppSection.allCases, selection: $selection) { section in
                Label(section.title, systemImage: section.symbolName)
                    .tag(section)
            }
            .navigationTitle("ihatefiles")
        } detail: {
            VStack(spacing: 0) {
                detailContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                ProgressStrip(jobs: jobManager.jobs)
            }
        }
        .frame(minWidth: 700, minHeight: 420)
    }

    @ViewBuilder
    private var detailContent: some View {
        switch selection ?? .downloader {
        case .queue:
            QueueView()
        case .downloader:
            DownloaderView()
        case .video:
            VideoToolView()
        case .image:
            ImageToolView()
        case let section:
            PlaceholderToolView(section: section)
        }
    }
}

#Preview {
    RootView()
        .environment(JobManager())
}
