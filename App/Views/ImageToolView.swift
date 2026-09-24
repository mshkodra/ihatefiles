import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Image section: convert, resize, or compress images natively via
/// ImageIO/CoreGraphics — no bundled binary. An operation picker switches
/// between the three panels; each enqueues an ImageConvertRunner.
struct ImageToolView: View {
    enum Operation: String, CaseIterable, Identifiable {
        case convert = "Convert"
        case resize = "Resize"
        case compress = "Compress"
        var id: String { rawValue }
    }

    @Environment(JobManager.self) private var jobManager
    @State private var operation: Operation = .convert
    @State private var inputURL: URL?
    @State private var targetFormat: UTType = .jpeg
    @State private var maxDimension: Double = 1024
    @State private var quality: Double = 0.7

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Image")
                .font(.title2.bold())

            operationPicker
            chooseFileRow

            switch operation {
            case .convert: convertControls
            case .resize: resizeControls
            case .compress: compressControls
            }

            actionButton

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .navigationTitle("Image")
    }

    private var operationPicker: some View {
        Picker("Operation", selection: $operation) {
            ForEach(Operation.allCases) { Text($0.rawValue).tag($0) }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 420)
    }

    private var chooseFileRow: some View {
        HStack(spacing: 8) {
            Button("Choose Image…", action: chooseInput)
                .buttonStyle(.bordered)
            if let inputURL {
                Text(inputURL.lastPathComponent)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
    }

    private var convertControls: some View {
        Picker("Format", selection: $targetFormat) {
            Text("JPEG").tag(UTType.jpeg)
            Text("PNG").tag(UTType.png)
        }
        .frame(maxWidth: 200)
    }

    private var resizeControls: some View {
        VStack(alignment: .leading) {
            Text("Max dimension: \(Int(maxDimension))px")
                .foregroundStyle(.secondary)
            Slider(value: $maxDimension, in: 64...4096, step: 16)
                .frame(maxWidth: 320)
        }
    }

    private var compressControls: some View {
        VStack(alignment: .leading) {
            Text("Quality: \(Int(quality * 100))%")
                .foregroundStyle(.secondary)
            Slider(value: $quality, in: 0.1...1.0)
                .frame(maxWidth: 320)
        }
    }

    private var actionButton: some View {
        Button(actionTitle, action: startJob)
            .buttonStyle(.borderedProminent)
            .disabled(inputURL == nil)
    }

    private var actionTitle: String {
        switch operation {
        case .convert: "Convert"
        case .resize: "Resize"
        case .compress: "Compress"
        }
    }

    private func chooseInput() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.image]
        if panel.runModal() == .OK {
            inputURL = panel.url
        }
    }

    private func startJob() {
        guard let inputURL else { return }
        let base = inputURL.deletingPathExtension()

        let (op, outputURL): (ImageConvertRunner.Operation, URL) = {
            switch operation {
            case .convert:
                let ext = targetFormat == .jpeg ? "jpg" : "png"
                let white = CGColor(red: 1, green: 1, blue: 1, alpha: 1)
                return (.convert(format: targetFormat, background: white), base.appendingPathExtension(ext))
            case .resize:
                return (.resize(maxDimension: maxDimension), base.appendingPathExtension("resized").appendingPathExtension(inputURL.pathExtension))
            case .compress:
                return (.compress(quality: quality), base.appendingPathExtension("compressed").appendingPathExtension("jpg"))
            }
        }()

        jobManager.enqueue(
            kind: .imageConvert,
            input: inputURL.lastPathComponent,
            runner: ImageConvertRunner(inputURL: inputURL, outputURL: outputURL, operation: op)
        )
        self.inputURL = nil
    }
}

#Preview {
    ImageToolView()
        .environment(JobManager())
}
