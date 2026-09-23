import Foundation

/// Accumulates ffmpeg's `-progress pipe:1` output — a stream of `key=value`
/// lines grouped into blocks, each block closed by a `progress=continue` or
/// `progress=end` line — into 0...1 progress fractions against a known
/// total duration.
///
/// Despite its name, `out_time_ms` is actually microseconds (a long-standing
/// ffmpeg naming quirk kept for backward compatibility) — dividing by
/// 1_000_000, not 1_000, is what makes this line up with `totalDuration`.
final class FfmpegProgressParser {
    private let totalDuration: TimeInterval
    private var outTimeMicroseconds: Double?

    init(totalDuration: TimeInterval) {
        self.totalDuration = totalDuration
    }

    /// Feed one line of ffmpeg's progress output. Returns a 0...1 fraction
    /// when `line` closes a progress block (a `progress=` line), else nil.
    func ingest(line: String) -> Double? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let equalsIndex = trimmed.firstIndex(of: "=") else { return nil }
        let key = trimmed[trimmed.startIndex..<equalsIndex]
        let value = trimmed[trimmed.index(after: equalsIndex)...]

        switch key {
        case "out_time_ms", "out_time_us":
            outTimeMicroseconds = Double(value)
            return nil
        case "progress":
            if value == "end" { return 1.0 }
            guard totalDuration > 0, let outTimeMicroseconds else { return nil }
            let fraction = (outTimeMicroseconds / 1_000_000.0) / totalDuration
            return min(max(fraction, 0), 1)
        default:
            return nil
        }
    }
}
