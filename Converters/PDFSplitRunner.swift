import Foundation
import PDFKit

/// Splits a PDF into two documents after the given 1-based page number, e.g.
/// splitAfterPage=3 on a 10-page PDF produces a 3-page part1 and 7-page
/// part2. Writes two new files — never touches the source.
final class PDFSplitRunner: JobRunner, @unchecked Sendable {
    private let inputURL: URL
    private let splitAfterPage: Int
    private let firstOutputURL: URL
    private let secondOutputURL: URL
    private var cancelled = false

    init(inputURL: URL, splitAfterPage: Int, firstOutputURL: URL, secondOutputURL: URL) {
        self.inputURL = inputURL
        self.splitAfterPage = splitAfterPage
        self.firstOutputURL = firstOutputURL
        self.secondOutputURL = secondOutputURL
    }

    func run(job: Job, progress: @escaping @Sendable (Double) -> Void) async throws {
        if cancelled { throw CancellationError() }
        guard let source = PDFDocument(url: inputURL) else { throw PDFConvertError.unreadablePDF(inputURL) }
        guard splitAfterPage > 0, splitAfterPage < source.pageCount else {
            throw PDFConvertError.invalidPageRange
        }

        let part1 = PDFDocument()
        for pageIndex in 0..<splitAfterPage {
            guard let page = source.page(at: pageIndex) else { continue }
            part1.insert(page, at: part1.pageCount)
        }
        guard part1.write(to: firstOutputURL) else { throw PDFConvertError.writeFailed }
        if cancelled { throw CancellationError() }
        progress(0.5)

        let part2 = PDFDocument()
        for pageIndex in splitAfterPage..<source.pageCount {
            guard let page = source.page(at: pageIndex) else { continue }
            part2.insert(page, at: part2.pageCount)
        }
        guard part2.write(to: secondOutputURL) else { throw PDFConvertError.writeFailed }

        if cancelled { throw CancellationError() }
        progress(1)
    }

    func cancel() {
        cancelled = true
    }
}
