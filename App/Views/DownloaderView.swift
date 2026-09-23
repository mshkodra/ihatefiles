import SwiftUI

/// Downloader section: paste a YouTube URL, download as MP4/MP3 or extract
/// just the thumbnail via the real yt-dlp runners. A playlist URL (detected
/// via its `list=` parameter) is resolved into one independent download Job
/// per video instead of one blocking job. Twitter/X lands in a later phase.
struct DownloaderView: View {
    @Environment(JobManager.self) private var jobManager
    @State private var urlText: String = ""
    @State private var isResolvingPlaylist = false
    @State private var resolutionError: String?

    private var trimmedURL: String {
        urlText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isPlaylist: Bool {
        YouTubePlaylistDetector.isPlaylistURL(trimmedURL)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("YouTube")
                .font(.title2.bold())

            TextField("Paste a YouTube video or playlist URL", text: $urlText)
                .textFieldStyle(.roundedBorder)
                .onSubmit(startMP4Download)
                .disabled(isResolvingPlaylist)

            HStack(spacing: 8) {
                Button("Download as MP4", action: startMP4Download)
                    .buttonStyle(.borderedProminent)
                    .disabled(trimmedURL.isEmpty || isResolvingPlaylist)

                Button("Download as MP3", action: startMP3Download)
                    .buttonStyle(.bordered)
                    .disabled(trimmedURL.isEmpty || isResolvingPlaylist)

                Button("Extract Thumbnail", action: startThumbnailDownload)
                    .buttonStyle(.bordered)
                    .disabled(trimmedURL.isEmpty || isResolvingPlaylist || isPlaylist)
            }

            if isResolvingPlaylist {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text("Resolving playlist…")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            } else if isPlaylist {
                Text("Playlist detected — every video will be queued individually.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let resolutionError {
                Text(resolutionError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Text("Twitter/X URLs aren't supported yet.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .navigationTitle("Downloader")
    }

    private func startMP4Download() {
        if isPlaylist {
            startPlaylistDownload(format: .mp4)
        } else {
            enqueue(kind: .youtubeVideo) { YouTubeVideoRunner(url: $0, format: .mp4) }
        }
    }

    private func startMP3Download() {
        if isPlaylist {
            startPlaylistDownload(format: .mp3)
        } else {
            enqueue(kind: .youtubeAudio) { YouTubeVideoRunner(url: $0, format: .mp3) }
        }
    }

    private func startThumbnailDownload() {
        enqueue(kind: .youtubeThumbnail) { ThumbnailRunner(url: $0) }
    }

    private func enqueue(kind: JobKind, makeRunner: (String) -> JobRunner) {
        guard !trimmedURL.isEmpty else { return }
        jobManager.enqueue(kind: kind, input: trimmedURL, runner: makeRunner(trimmedURL))
        urlText = ""
    }

    private func startPlaylistDownload(format: DownloadFormat) {
        let url = trimmedURL
        resolutionError = nil
        isResolvingPlaylist = true
        Task { @MainActor in
            defer { isResolvingPlaylist = false }
            do {
                _ = try await YouTubePlaylistResolver.resolveAndEnqueue(
                    playlistURL: url, format: format, jobManager: jobManager
                )
                urlText = ""
            } catch {
                resolutionError = "Couldn't resolve playlist: \(error.localizedDescription)"
            }
        }
    }
}

#Preview {
    DownloaderView()
        .environment(JobManager())
}
