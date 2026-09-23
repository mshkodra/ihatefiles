import Foundation

/// Parses progress fractions (0...1) out of yt-dlp's `--newline`-mode stdout
/// lines (e.g. `[download]  45.2% of  10.00MiB at  1.20MiB/s ETA 00:05`).
/// Non-progress lines (metadata, merging, etc.) return nil.
enum YtDlpProgressParser {
    private static let progressRegex = try! NSRegularExpression(
        pattern: #"^\[download\]\s+([\d.]+)%"#
    )

    static func parseProgress(from line: String) -> Double? {
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        guard let match = progressRegex.firstMatch(in: line, range: range),
              let percentRange = Range(match.range(at: 1), in: line),
              let percent = Double(line[percentRange])
        else {
            return nil
        }
        return min(max(percent / 100.0, 0), 1)
    }
}
