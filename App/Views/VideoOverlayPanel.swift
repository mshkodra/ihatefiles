import SwiftUI
import AppKit

/// Picture-in-picture: overlays a webcam clip onto a screen recording's
/// top-right corner at 20% of its width.
struct VideoOverlayPanel: View {
    @Environment(JobManager.self) private var jobManager
    @State private var screenURL: URL?
    @State private var webcamURL: URL?

    private var outputURL: URL? {
        guard let screenURL else { return nil }
        let base = screenURL.deletingPathExtension().lastPathComponent
        return screenURL.deletingLastPathComponent()
            .appendingPathComponent("\(base)-overlay")
            .appendingPathExtension("mp4")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            fileRow(label: "Screen recording", url: screenURL) { chooseFile { screenURL = $0 } }
            fileRow(label: "Webcam clip", url: webcamURL) { chooseFile { webcamURL = $0 } }

            Text("Webcam is scaled to 20% of the screen recording's width and placed in the top-right corner.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button("Overlay", action: startOverlay)
                .buttonStyle(.borderedProminent)
                .disabled(screenURL == nil || webcamURL == nil)
        }
    }

    @ViewBuilder
    private func fileRow(label: String, url: URL?, choose: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.subheadline).foregroundStyle(.secondary)
            HStack(spacing: 8) {
                Button("Choose…", action: choose)
                    .buttonStyle(.bordered)
                if let url {
                    Text(url.lastPathComponent)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
        }
    }

    private func chooseFile(_ assign: @escaping (URL?) -> Void) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.movie, .video, .mpeg4Movie]
        if panel.runModal() == .OK {
            assign(panel.url)
        }
    }

    private func startOverlay() {
        guard let screenURL, let webcamURL, let outputURL else { return }
        jobManager.enqueue(
            kind: .videoOverlay,
            input: screenURL.lastPathComponent,
            runner: VideoOverlayRunner(screenURL: screenURL, webcamURL: webcamURL, outputURL: outputURL)
        )
        self.screenURL = nil
        self.webcamURL = nil
    }
}

#Preview {
    VideoOverlayPanel()
        .environment(JobManager())
        .padding(24)
}
