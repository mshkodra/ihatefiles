import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Merges 2+ PDFs, in the order added, into one new document.
struct PDFMergePanel: View {
    @Environment(JobManager.self) private var jobManager
    @State private var inputURLs: [URL] = []

    private var outputURL: URL? {
        guard let first = inputURLs.first else { return nil }
        return first.deletingLastPathComponent()
            .appendingPathComponent("merged")
            .appendingPathExtension("pdf")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button("Add PDFs…", action: addInputs)
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

            Button("Merge", action: startMerge)
                .buttonStyle(.borderedProminent)
                .disabled(inputURLs.count < 2)
        }
    }

    private func addInputs() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.pdf]
        if panel.runModal() == .OK {
            inputURLs.append(contentsOf: panel.urls)
        }
    }

    private func startMerge() {
        guard inputURLs.count >= 2, let outputURL else { return }
        jobManager.enqueue(
            kind: .pdfMerge,
            input: "\(inputURLs.count) PDFs",
            runner: PDFMergeRunner(inputURLs: inputURLs, outputURL: outputURL)
        )
        inputURLs = []
    }
}

#Preview {
    PDFMergePanel()
        .environment(JobManager())
        .padding(24)
}
