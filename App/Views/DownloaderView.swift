import SwiftUI

/// Downloader section: paste a URL and download it. YouTube URLs support
/// MP4/MP3/thumbnail via the real yt-dlp runners, with playlists (detected
/// via `list=`) resolved into one independent download Job per video.
/// Twitter/X URLs probe available formats first, then let the user pick one
/// (or auto-best) before downloading.
struct DownloaderView: View {
    @Environment(JobManager.self) private var jobManager
    @State private var urlText: String = ""
    @State private var isResolvingPlaylist = false
    @State private var resolutionError: String?

    @State private var isProbingTwitter = false
    @State private var twitterError: String?
    @State private var twitterFormats: [TwitterFormat] = []
    @State private var showTwitterPicker = false
    @State private var twitterURLBeingHandled = ""

    private var trimmedURL: String {
        urlText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isPlaylist: Bool {
        YouTubePlaylistDetector.isPlaylistURL(trimmedURL)
    }

    private var isTwitter: Bool {
        TwitterURLDetector.isTwitterURL(trimmedURL)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(isTwitter ? "Twitter / X" : "YouTube")
                .font(.title2.bold())

            TextField("Paste a YouTube or Twitter/X URL", text: $urlText)
                .textFieldStyle(.roundedBorder)
                .onSubmit(primaryAction)
                .disabled(isResolvingPlaylist || isProbingTwitter)

            if isTwitter {
                twitterControls
            } else {
                youtubeControls
            }

            if let resolutionError {
                Text(resolutionError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            if let twitterError {
                Text(twitterError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .navigationTitle("Downloader")
        .sheet(isPresented: $showTwitterPicker) {
            TwitterFormatPickerSheet(
                formats: twitterFormats,
                onSelect: { formatId in
                    jobManager.enqueue(
                        kind: .twitter,
                        input: twitterURLBeingHandled,
                        runner: TwitterDownloadRunner(url: twitterURLBeingHandled, formatId: formatId)
                    )
                    showTwitterPicker = false
                    urlText = ""
                },
                onCancel: { showTwitterPicker = false }
            )
        }
    }

    @ViewBuilder
    private var youtubeControls: some View {
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
    }

    @ViewBuilder
    private var twitterControls: some View {
        HStack(spacing: 8) {
            Button("Fetch Formats", action: startTwitterProbe)
                .buttonStyle(.borderedProminent)
                .disabled(trimmedURL.isEmpty || isProbingTwitter)
        }

        if isProbingTwitter {
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Fetching available formats…")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private func primaryAction() {
        if isTwitter {
            startTwitterProbe()
        } else {
            startMP4Download()
        }
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

    private func startTwitterProbe() {
        let url = trimmedURL
        guard !url.isEmpty else { return }
        twitterURLBeingHandled = url
        twitterError = nil
        isProbingTwitter = true
        Task { @MainActor in
            defer { isProbingTwitter = false }
            do {
                twitterFormats = try await TwitterProbeRunner.fetchFormats(url: url)
                showTwitterPicker = true
            } catch {
                twitterError = "Couldn't fetch formats: \(error.localizedDescription)"
            }
        }
    }
}

#Preview {
    DownloaderView()
        .environment(JobManager())
}
