import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Rotates every page by 90/180/270°, or extracts a page range into a new
/// document.
struct PDFPageOpsPanel: View {
    enum Mode: String, CaseIterable, Identifiable {
        case rotate = "Rotate"
        case extract = "Extract"
        var id: String { rawValue }
    }

    @Environment(JobManager.self) private var jobManager
    @State private var mode: Mode = .rotate
    @State private var inputURL: URL?
    @State private var rotationDegrees = 90
    @State private var startPageText = ""
    @State private var endPageText = ""

    private var outputURL: URL? {
        guard let inputURL else { return nil }
        let base = inputURL.deletingPathExtension().lastPathComponent
        let suffix = mode == .rotate ? "rotated" : "extracted"
        return inputURL.deletingLastPathComponent()
            .appendingPathComponent("\(base)-\(suffix)")
            .appendingPathExtension("pdf")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Picker("Mode", selection: $mode) {
                ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.radioGroup)

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

            switch mode {
            case .rotate:
                Picker("Rotate by", selection: $rotationDegrees) {
                    Text("90°").tag(90)
                    Text("180°").tag(180)
                    Text("270°").tag(270)
                }
                .frame(maxWidth: 200)
            case .extract:
                HStack {
                    TextField("First page", text: $startPageText)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 100)
                    Text("to")
                    TextField("Last page", text: $endPageText)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 100)
                }
            }

            Button(mode.rawValue, action: startJob)
                .buttonStyle(.borderedProminent)
                .disabled(!canStart)
        }
    }

    private var canStart: Bool {
        guard inputURL != nil else { return false }
        switch mode {
        case .rotate: return true
        case .extract: return Int(startPageText) != nil && Int(endPageText) != nil
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

    private func startJob() {
        guard let inputURL, let outputURL else { return }
        switch mode {
        case .rotate:
            jobManager.enqueue(
                kind: .pdfRotate,
                input: inputURL.lastPathComponent,
                runner: PDFPageOpsRunner(inputURL: inputURL, outputURL: outputURL, operation: .rotate(degrees: rotationDegrees))
            )
        case .extract:
            guard let start = Int(startPageText), let end = Int(endPageText), start <= end else { return }
            jobManager.enqueue(
                kind: .pdfExtract,
                input: inputURL.lastPathComponent,
                runner: PDFPageOpsRunner(inputURL: inputURL, outputURL: outputURL, operation: .extract(range: start...end))
            )
        }
        self.inputURL = nil
        self.startPageText = ""
        self.endPageText = ""
    }
}

#Preview {
    PDFPageOpsPanel()
        .environment(JobManager())
        .padding(24)
}
