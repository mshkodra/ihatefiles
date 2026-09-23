import Foundation

/// One entry in a `--flat-playlist --dump-json` listing.
struct YouTubePlaylistEntry: Equatable {
    let id: String
    let title: String
}

/// Parses yt-dlp's `--flat-playlist --dump-json` output, which prints one
/// compact JSON object per line, one per playlist video.
enum YouTubePlaylistParser {
    static func parseEntry(fromJSONLine line: String) -> YouTubePlaylistEntry? {
        guard let data = line.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let id = object["id"] as? String
        else { return nil }
        return YouTubePlaylistEntry(id: id, title: (object["title"] as? String) ?? id)
    }
}

/// Enumerates a playlist's videos via a quick `--flat-playlist` yt-dlp call,
/// then enqueues one independent download Job per video through the normal
/// `JobManager.enqueue` path — each subject to the usual download
/// concurrency cap, not one giant job that occupies a slot for the whole
/// playlist's duration. Children share a `parentId` so the Queue can
/// associate them with the playlist that spawned them.
enum YouTubePlaylistResolver {
    struct EmptyPlaylistError: LocalizedError {
        var errorDescription: String? { "No videos found in that playlist." }
    }

    @MainActor
    static func resolveAndEnqueue(
        playlistURL: String,
        format: DownloadFormat,
        jobManager: JobManager
    ) async throws -> Int {
        let entries = try await fetchEntries(playlistURL: playlistURL)
        guard !entries.isEmpty else { throw EmptyPlaylistError() }

        let parentId = UUID()
        let kind: JobKind = (format == .mp3) ? .youtubeAudio : .youtubeVideo
        for entry in entries {
            let videoURL = "https://www.youtube.com/watch?v=\(entry.id)"
            jobManager.enqueue(
                kind: kind,
                input: entry.title,
                runner: YouTubeVideoRunner(url: videoURL, format: format),
                parentId: parentId
            )
        }
        return entries.count
    }

    private static func fetchEntries(playlistURL: String) async throws -> [YouTubePlaylistEntry] {
        let ytDlpURL = try BinaryLocator.ytDlpURL
        let collector = EntryCollector()

        try await ProcessRunning.run(
            executableURL: ytDlpURL,
            arguments: ["--flat-playlist", "--dump-json", playlistURL],
            onStdoutLine: { line in
                if let entry = YouTubePlaylistParser.parseEntry(fromJSONLine: line) {
                    collector.append(entry)
                }
            }
        )
        return collector.entries
    }
}

/// Thread-safe accumulator for entries parsed off yt-dlp's stdout, which
/// arrives on a background readability-handler queue.
private final class EntryCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [YouTubePlaylistEntry] = []

    func append(_ entry: YouTubePlaylistEntry) {
        lock.lock()
        storage.append(entry)
        lock.unlock()
    }

    var entries: [YouTubePlaylistEntry] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }
}
