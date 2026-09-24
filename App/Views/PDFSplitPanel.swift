import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Splits a PDF into two documents after a given page number.
struct PDFSplitPanel: View {
    @Environment(JobManager.self) private var jobManager
    @State private var inputURL: URL?
    @State private var splitAfterPageText = ""

    private var splitAfterPage: Int? { Int(splitAfterPageText) }

    private func outputURL(suffix: String) -> URL? {
        guard let inputURL else { return nil }
        let base = inputURL.deletingPathExtension().lastPathComponent
        return inputURL.deletingLastPathComponent()
            .appendingPathComponent("\(base)-\(suffix)")
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

            TextField("Split after page", text: $splitAfterPageText)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 200)

            Button("Split", action: startSplit)
                .buttonStyle(.borderedProminent)
                .disabled(inputURL == nil || splitAfterPage == nil || (splitAfterPage ?? 0) <= 0)
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

    private func startSplit() {
        guard let inputURL, let splitAfterPage,
              let firstOutputURL = outputURL(suffix: "part1"),
              let secondOutputURL = outputURL(suffix: "part2") else { return }
        jobManager.enqueue(
            kind: .pdfSplit,
            input: inputURL.lastPathComponent,
            runner: PDFSplitRunner(
                inputURL: inputURL,
                splitAfterPage: splitAfterPage,
                firstOutputURL: firstOutputURL,
                secondOutputURL: secondOutputURL
            )
        )
        self.inputURL = nil
        self.splitAfterPageText = ""
    }
}

#Preview {
    PDFSplitPanel()
        .environment(JobManager())
        .padding(24)
}
