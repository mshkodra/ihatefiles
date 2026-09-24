import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Reduces file size by re-rendering pages at a lower JPEG quality.
struct PDFCompressPanel: View {
    @Environment(JobManager.self) private var jobManager
    @State private var inputURL: URL?
    @State private var quality: Double = 0.5

    private var outputURL: URL? {
        guard let inputURL else { return nil }
        let base = inputURL.deletingPathExtension().lastPathComponent
        return inputURL.deletingLastPathComponent()
            .appendingPathComponent("\(base)-compressed")
            .appendingPathExtension("pdf")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Button("Choose PDF…", action: chooseInput)
                    .buttonStyle(.bordered)
                if let inputURL {
                    Text(inputURL.lastPathComponent)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            VStack(alignment: .leading) {
                Text("Quality: \(Int(quality * 100))%")
                    .foregroundStyle(.secondary)
                Slider(value: $quality, in: 0.1...1.0)
                    .frame(maxWidth: 320)
            }

            Text("Pages are re-rendered as images — best for shrinking file size, not for keeping text searchable.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button("Compress", action: startCompress)
                .buttonStyle(.borderedProminent)
                .disabled(inputURL == nil)
        }
    }

    private func chooseInput() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.pdf]
        if panel.runModal() == .OK {
            inputURL = panel.url
        }
    }

    private func startCompress() {
        guard let inputURL, let outputURL else { return }
        jobManager.enqueue(
            kind: .pdfCompress,
            input: inputURL.lastPathComponent,
            runner: PDFCompressRunner(inputURL: inputURL, outputURL: outputURL, quality: quality)
        )
        self.inputURL = nil
    }
}

#Preview {
    PDFCompressPanel()
        .environment(JobManager())
        .padding(24)
}
