import SwiftUI
import AppKit

/// Video section: convert, split, concatenate, or overlay videos via the
/// bundled ffmpeg, with real progress. An operation picker switches between
/// Convert (inline below) and the Split/Concat/Overlay panels.
struct VideoToolView: View {
    enum Operation: String, CaseIterable, Identifiable {
        case convert = "Convert"
        case split = "Split"
        case concat = "Concatenate"
        case overlay = "Overlay"
        var id: String { rawValue }
    }

    @Environment(JobManager.self) private var jobManager
    @State private var operation: Operation = .convert
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

            switch operation {
            case .convert: convertPanel
            case .split: VideoSplitPanel()
            case .concat: VideoConcatPanel()
            case .overlay: VideoOverlayPanel()
            }

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .navigationTitle("Video")
    }

    private var operationPicker: some View {
        Picker("Operation", selection: $operation) {
            ForEach(Operation.allCases) { Text($0.rawValue).tag($0) }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 420)
    }

    @ViewBuilder
    private var convertPanel: some View {
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
