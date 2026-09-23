import SwiftUI
import AppKit

/// Concatenates 2+ videos in order. Fast mode stream-copies (needs matching
/// codecs/resolution/fps); Compatible mode re-encodes and tolerates
/// mismatches.
struct VideoConcatPanel: View {
    @Environment(JobManager.self) private var jobManager
    @State private var inputURLs: [URL] = []
    @State private var mode: VideoConcatRunner.Mode = .fast

    private var outputURL: URL? {
        guard let first = inputURLs.first else { return nil }
        let base = first.deletingPathExtension().lastPathComponent
        return first.deletingLastPathComponent()
            .appendingPathComponent("\(base)-concat")
            .appendingPathExtension("mp4")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button("Add Videos…", action: addInputs)
                .buttonStyle(.bordered)

            if !inputURLs.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(inputURLs.enumerated()), id: \.offset) { index, url in
                        HStack {
                            Text("\(index + 1). \(url.lastPathComponent)")
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            Button("Remove") { inputURLs.remove(at: index) }
                                .buttonStyle(.plain)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Picker("Mode", selection: $mode) {
                Text("Fast (same codec/resolution)").tag(VideoConcatRunner.Mode.fast)
                Text("Compatible (re-encodes)").tag(VideoConcatRunner.Mode.compatible)
            }
            .pickerStyle(.radioGroup)

            Button("Concatenate", action: startConcat)
                .buttonStyle(.borderedProminent)
                .disabled(inputURLs.count < 2)
        }
    }

    private func addInputs() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.movie, .video, .mpeg4Movie]
        if panel.runModal() == .OK {
            inputURLs.append(contentsOf: panel.urls)
        }
    }

    private func startConcat() {
        guard inputURLs.count >= 2, let outputURL else { return }
        jobManager.enqueue(
            kind: .videoConcat,
            input: "\(inputURLs.count) videos",
            runner: VideoConcatRunner(inputURLs: inputURLs, outputURL: outputURL, mode: mode)
        )
        inputURLs = []
    }
}

#Preview {
    VideoConcatPanel()
        .environment(JobManager())
        .padding(24)
}
