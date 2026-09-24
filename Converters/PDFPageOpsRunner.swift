import Foundation
import PDFKit

/// Rotates every page of a PDF, or extracts a page range into a new
/// document. Grouped together since both are simple page-level transforms.
/// Writes a new file — never touches the source.
final class PDFPageOpsRunner: JobRunner, @unchecked Sendable {
    enum Operation {
        /// Rotate every page by `degrees` (added to each page's existing rotation).
        case rotate(degrees: Int)
        /// Keep only pages in `range` (1-based, inclusive) in the output.
        case extract(range: ClosedRange<Int>)
    }

    private let inputURL: URL
    private let outputURL: URL
    private let operation: Operation
    private var cancelled = false

    init(inputURL: URL, outputURL: URL, operation: Operation) {
        self.inputURL = inputURL
        self.outputURL = outputURL
        self.operation = operation
    }

    func run(job: Job, progress: @escaping @Sendable (Double) -> Void) async throws {
        if cancelled { throw CancellationError() }
        guard let source = PDFDocument(url: inputURL) else { throw PDFConvertError.unreadablePDF(inputURL) }

        switch operation {
        case let .rotate(degrees):
            guard degrees % 90 == 0 else { throw PDFConvertError.invalidPageRange }
            for pageIndex in 0..<source.pageCount {
                guard let page = source.page(at: pageIndex) else { continue }
                page.rotation = normalized(page.rotation + degrees)
            }
            guard source.write(to: outputURL) else { throw PDFConvertError.writeFailed }

        case let .extract(range):
            guard range.lowerBound >= 1, range.upperBound <= source.pageCount else {
                throw PDFConvertError.invalidPageRange
            }
            let extracted = PDFDocument()
            for pageIndex in (range.lowerBound - 1)..<range.upperBound {
                guard let page = source.page(at: pageIndex) else { continue }
                extracted.insert(page, at: extracted.pageCount)
            }
            guard extracted.write(to: outputURL) else { throw PDFConvertError.writeFailed }
        }

        if cancelled { throw CancellationError() }
        progress(1)
    }

    func cancel() {
        cancelled = true
    }

    /// Normalizes a rotation value into PDFKit's expected 0/90/180/270 range.
    private func normalized(_ degrees: Int) -> Int {
        ((degrees % 360) + 360) % 360
    }
}
