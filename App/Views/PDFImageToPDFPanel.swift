import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Converts image(s) into a new PDF, or appends them to an existing PDF —
/// always writing a new file. See ImageToPDFRunner for the overwrite-bug
/// fix vs. the old append_image_to_pdf.py script.
struct PDFImageToPDFPanel: View {
    @Environment(JobManager.self) private var jobManager
    @State private var imageURLs: [URL] = []
    @State private var existingPDFURL: URL?
    @State private var errorMessage: String?

    private var outputURL: URL? {
        if let existingPDFURL {
            let base = existingPDFURL.deletingPathExtension().lastPathComponent
            return existingPDFURL.deletingLastPathComponent()
                .appendingPathComponent("\(base)-with-image")
                .appendingPathExtension("pdf")
        }
        guard let first = imageURLs.first else { return nil }
        return first.deletingLastPathComponent()
            .appendingPathComponent("images")
            .appendingPathExtension("pdf")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button("Add Images…", action: addImages)
                .buttonStyle(.bordered)

            if !imageURLs.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(imageURLs.enumerated()), id: \.offset) { index, url in
                        HStack {
                            Text("\(index + 1). \(url.lastPathComponent)")
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            Button("Remove") { imageURLs.remove(at: index) }
                                .buttonStyle(.plain)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            existingPDFRow

            if let outputURL {
                Text("Saves as \(outputURL.lastPathComponent) — the original is never overwritten")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Button("Create PDF", action: startJob)
                .buttonStyle(.borderedProminent)
                .disabled(imageURLs.isEmpty)
        }
    }

    private var existingPDFRow: some View {
        HStack(spacing: 8) {
            Button(existingPDFURL == nil ? "Append to Existing PDF (optional)…" : "Change Target PDF…", action: chooseExistingPDF)
                .buttonStyle(.bordered)
            if let existingPDFURL {
                Text(existingPDFURL.lastPathComponent)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Button("Clear") { self.existingPDFURL = nil }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func addImages() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.image]
        if panel.runModal() == .OK {
            imageURLs.append(contentsOf: panel.urls)
        }
    }

    private func chooseExistingPDF() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.pdf]
        if panel.runModal() == .OK {
            existingPDFURL = panel.url
        }
    }

    private func startJob() {
        guard !imageURLs.isEmpty, let outputURL else { return }
        do {
            let runner = try ImageToPDFRunner(imageURLs: imageURLs, existingPDFURL: existingPDFURL, outputURL: outputURL)
            jobManager.enqueue(kind: .pdfImageToPDF, input: "\(imageURLs.count) image(s)", runner: runner)
            imageURLs = []
            existingPDFURL = nil
            errorMessage = nil
        } catch {
            errorMessage = "Couldn't start: \(error)"
        }
    }
}

#Preview {
    PDFImageToPDFPanel()
        .environment(JobManager())
        .padding(24)
}
