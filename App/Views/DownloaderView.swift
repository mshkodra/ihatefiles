import SwiftUI

/// Downloader section: paste a YouTube URL, download as MP4 via the real
/// yt-dlp runner. MP3/thumbnail/playlist/Twitter formats land in later phases.
struct DownloaderView: View {
    @Environment(JobManager.self) private var jobManager
    @State private var urlText: String = ""

    private var trimmedURL: String {
        urlText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("YouTube")
                .font(.title2.bold())

            TextField("Paste a YouTube video URL", text: $urlText)
                .textFieldStyle(.roundedBorder)
                .onSubmit(startDownload)

            HStack(spacing: 8) {
                Button("Download as MP4", action: startDownload)
                    .buttonStyle(.borderedProminent)
                    .disabled(trimmedURL.isEmpty)

                Button("Download as MP3") {}
                    .buttonStyle(.bordered)
                    .disabled(true)
                    .help("Coming in a later phase")

                Button("Extract Thumbnail") {}
                    .buttonStyle(.bordered)
                    .disabled(true)
                    .help("Coming in a later phase")
            }

            Text("Playlist and Twitter/X URLs aren't supported yet.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .navigationTitle("Downloader")
    }

    private func startDownload() {
        guard !trimmedURL.isEmpty else { return }
        jobManager.enqueue(
            kind: .youtubeVideo,
            input: trimmedURL,
            runner: YouTubeVideoRunner(url: trimmedURL)
        )
        urlText = ""
    }
}

#Preview {
    DownloaderView()
        .environment(JobManager())
}
