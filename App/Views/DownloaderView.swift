import SwiftUI

/// Downloader section: paste a YouTube URL, download as MP4/MP3 or extract
/// just the thumbnail via the real yt-dlp runners. Playlist/Twitter formats
/// land in later phases.
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
                .onSubmit(startMP4Download)

            HStack(spacing: 8) {
                Button("Download as MP4", action: startMP4Download)
                    .buttonStyle(.borderedProminent)
                    .disabled(trimmedURL.isEmpty)

                Button("Download as MP3", action: startMP3Download)
                    .buttonStyle(.bordered)
                    .disabled(trimmedURL.isEmpty)

                Button("Extract Thumbnail", action: startThumbnailDownload)
                    .buttonStyle(.bordered)
                    .disabled(trimmedURL.isEmpty)
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

    private func startMP4Download() {
        enqueue(kind: .youtubeVideo) { YouTubeVideoRunner(url: $0, format: .mp4) }
    }

    private func startMP3Download() {
        enqueue(kind: .youtubeAudio) { YouTubeVideoRunner(url: $0, format: .mp3) }
    }

    private func startThumbnailDownload() {
        enqueue(kind: .youtubeThumbnail) { ThumbnailRunner(url: $0) }
    }

    private func enqueue(kind: JobKind, makeRunner: (String) -> JobRunner) {
        guard !trimmedURL.isEmpty else { return }
        jobManager.enqueue(kind: kind, input: trimmedURL, runner: makeRunner(trimmedURL))
        urlText = ""
    }
}

#Preview {
    DownloaderView()
        .environment(JobManager())
}
