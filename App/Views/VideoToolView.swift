import SwiftUI
import AppKit

/// Video section: pick a file and convert it to H.264/AAC MP4 via the bundled
/// ffmpeg, with real progress. Split/concat/overlay are separate operations
/// added in a later phase — this view is structured so those can slot in
/// alongside Convert without disturbing it.
struct VideoToolView: View {
    @Environment(JobManager.self) private var jobManager
    @State private var inputURL: URL?

    private var outputURL: URL? {
        guard let inputURL else { return nil }
        let base = inputURL.deletingPathExtension().lastPathComponent
        return inputURL.deletingLastPathComponent()
            .appendingPathComponent("\(base)-converted")
            .appendingPathExtension("mp4")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Video")
                .font(.title2.bold())

            operationPicker

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

            if let outputURL {
                Text("Saves as \(outputURL.lastPathComponent)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button("Convert to MP4", action: startConvert)
                .buttonStyle(.borderedProminent)
                .disabled(inputURL == nil)

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .navigationTitle("Video")
    }

    /// Only Convert exists today; Split/Concat/Overlay are added as further
    /// cases in a later phase, following the same enqueue pattern below.
    @ViewBuilder
    private var operationPicker: some View {
        Text("Convert")
            .font(.subheadline)
            .foregroundStyle(.secondary)
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

    private func startConvert() {
        guard let inputURL, let outputURL else { return }
        jobManager.enqueue(
            kind: .videoConvert,
            input: inputURL.lastPathComponent,
            runner: VideoConvertRunner(inputURL: inputURL, outputURL: outputURL)
        )
        self.inputURL = nil
    }
}

#Preview {
    VideoToolView()
        .environment(JobManager())
}
