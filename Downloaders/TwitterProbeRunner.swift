import Foundation

/// One video-bearing format available on a Twitter/X post, as reported by
/// `yt-dlp -j`.
struct TwitterFormat: Identifiable, Equatable {
    var id: String { formatId }
    let formatId: String
    let note: String
    let tbr: Double?
    let ext: String
    let filesizeBytes: Int64?
}

/// Parses yt-dlp's `-j` (dump-json) output for a single URL into the list of
/// video-bearing formats, filtered and sorted the same way twitter_download.py
/// did: drop formats with no video stream, sort by bitrate descending.
enum TwitterFormatParser {
    static func parseFormats(fromJSON jsonLine: String) -> [TwitterFormat] {
        guard let data = jsonLine.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rawFormats = object["formats"] as? [[String: Any]]
        else { return [] }

        let videoFormats = rawFormats.compactMap(parseFormat).filter { hasVideoStream($0.rawVcodec) }
        return videoFormats
            .sorted { ($0.format.tbr ?? -1) > ($1.format.tbr ?? -1) }
            .map(\.format)
    }

    private static func hasVideoStream(_ vcodec: Any?) -> Bool {
        guard let vcodec = vcodec as? String else { return false }
        return vcodec != "none"
    }

    private static func parseFormat(_ raw: [String: Any]) -> (format: TwitterFormat, rawVcodec: Any?)? {
        guard let formatId = raw["format_id"] as? String else { return nil }

        let note: String
        if let formatNote = raw["format_note"] as? String, !formatNote.isEmpty {
            note = formatNote
        } else if let width = raw["width"] as? Int, let height = raw["height"] as? Int {
            note = "\(width)x\(height)"
        } else {
            note = formatId
        }

        let tbr = (raw["tbr"] as? NSNumber)?.doubleValue
        let ext = (raw["ext"] as? String) ?? "mp4"
        let filesize = (raw["filesize"] as? NSNumber)?.int64Value
            ?? (raw["filesize_approx"] as? NSNumber)?.int64Value

        let format = TwitterFormat(formatId: formatId, note: note, tbr: tbr, ext: ext, filesizeBytes: filesize)
        return (format, raw["vcodec"])
    }
}

/// Probes a Twitter/X URL's available formats without downloading, via the
/// bundled yt-dlp binary's `-j` (dump-json, implies simulate-only) flag.
enum TwitterProbeRunner {
    static func fetchFormats(url: String) async throws -> [TwitterFormat] {
        let ytDlpURL = try BinaryLocator.ytDlpURL
        let collector = JSONLineCollector()

        try await ProcessRunning.run(
            executableURL: ytDlpURL,
            arguments: ["-j", url],
            onStdoutLine: { line in collector.append(line) }
        )

        // yt-dlp prints one JSON object per line for a single URL; take the last
        // non-empty line in case any warnings/other output slipped onto stdout.
        guard let jsonLine = collector.lines.last(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) else {
            return []
        }
        return TwitterFormatParser.parseFormats(fromJSON: jsonLine)
    }
}

private final class JSONLineCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String] = []

    func append(_ line: String) {
        lock.lock()
        storage.append(line)
        lock.unlock()
    }

    var lines: [String] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }
}
