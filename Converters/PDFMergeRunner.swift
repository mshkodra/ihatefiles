import Foundation
import PDFKit

/// Merges 2+ PDFs, in the given order, into one new document. Never touches
/// an input file — only ever writes to `outputURL`. A conversion
/// (JobKind.pdfMerge), not a download — JobManager runs it immediately,
/// uncapped.
final class PDFMergeRunner: JobRunner, @unchecked Sendable {
    private let inputURLs: [URL]
    private let outputURL: URL
    private var cancelled = false

    init(inputURLs: [URL], outputURL: URL) {
        self.inputURLs = inputURLs
        self.outputURL = outputURL
    }

    func run(job: Job, progress: @escaping @Sendable (Double) -> Void) async throws {
        if cancelled { throw CancellationError() }
        guard inputURLs.count >= 2 else { throw PDFConvertError.tooFewInputs }

        let merged = PDFDocument()
        for (index, url) in inputURLs.enumerated() {
            if cancelled { throw CancellationError() }
            guard let source = PDFDocument(url: url) else { throw PDFConvertError.unreadablePDF(url) }
            for pageIndex in 0..<source.pageCount {
                guard let page = source.page(at: pageIndex) else { continue }
                merged.insert(page, at: merged.pageCount)
            }
            progress(Double(index + 1) / Double(inputURLs.count) * 0.9)
        }

        guard merged.write(to: outputURL) else { throw PDFConvertError.writeFailed }
        if cancelled { throw CancellationError() }
        progress(1)
    }

    func cancel() {
        cancelled = true
    }
}
