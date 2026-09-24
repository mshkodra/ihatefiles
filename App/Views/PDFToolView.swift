import SwiftUI

/// PDF section: merge, split, rotate/extract, compress, or convert image(s)
/// to PDF via PDFKit — no bundled binary. An operation picker switches
/// between panels, each enqueuing its own runner.
struct PDFToolView: View {
    enum Operation: String, CaseIterable, Identifiable {
        case merge = "Merge"
        case split = "Split"
        case pageOps = "Rotate/Extract"
        case compress = "Compress"
        case imageToPDF = "Image → PDF"
        var id: String { rawValue }
    }

    @State private var operation: Operation = .merge

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("PDF")
                .font(.title2.bold())

            operationPicker

            switch operation {
            case .merge: PDFMergePanel()
            case .split: PDFSplitPanel()
            case .pageOps: PDFPageOpsPanel()
            case .compress: PDFCompressPanel()
            case .imageToPDF: PDFImageToPDFPanel()
            }

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .navigationTitle("PDF")
    }

    private var operationPicker: some View {
        Picker("Operation", selection: $operation) {
            ForEach(Operation.allCases) { Text($0.rawValue).tag($0) }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 560)
    }
}

#Preview {
    PDFToolView()
        .environment(JobManager())
}
