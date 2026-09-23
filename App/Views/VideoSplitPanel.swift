import SwiftUI
import AppKit

/// Splits a video into two parts at a timestamp via stream-copy ffmpeg calls
/// (fast, but split points snap to the nearest keyframe).
struct VideoSplitPanel: View {
    @Environment(JobManager.self) private var jobManager
    @State private var inputURL: URL?
    @State private var splitSecondsText = ""

    private var splitSeconds: Double? { Double(splitSecondsText) }

    private var firstOutputURL: URL? { outputURL(suffix: "part1") }
    private var secondOutputURL: URL? { outputURL(suffix: "part2") }

    private func outputURL(suffix: String) -> URL? {
        guard let inputURL else { return nil }
        let base = inputURL.deletingPathExtension().lastPathComponent
        return inputURL.deletingLastPathComponent()
            .appendingPathComponent("\(base)-\(suffix)")
            .appendingPathExtension(inputURL.pathExtension.isEmpty ? "mp4" : inputURL.pathExtension)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Button("Choose Video…", action: chooseInput)
                    .buttonStyle(.bordered)
                if let inputURL {
                    Text(inputURL.lastPathComponent)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            TextField("Split at (seconds)", text: $splitSecondsText)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 200)

            Text("Split points snap to the nearest keyframe (no re-encoding).")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button("Split", action: startSplit)
                .buttonStyle(.borderedProminent)
                .disabled(inputURL == nil || splitSeconds == nil || (splitSeconds ?? 0) <= 0)
        }
    }

    private func chooseInput() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.movie, .video, .mpeg4Movie]
        if panel.runModal() == .OK {
            inputURL = panel.url
        }
    }

    private func startSplit() {
        guard let inputURL, let splitSeconds, let firstOutputURL, let secondOutputURL else { return }
        jobManager.enqueue(
            kind: .videoSplit,
            input: inputURL.lastPathComponent,
            runner: VideoSplitRunner(
                inputURL: inputURL,
                splitSeconds: splitSeconds,
                firstOutputURL: firstOutputURL,
                secondOutputURL: secondOutputURL
            )
        )
        self.inputURL = nil
        self.splitSecondsText = ""
    }
}

#Preview {
    VideoSplitPanel()
        .environment(JobManager())
        .padding(24)
}
