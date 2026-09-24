import Foundation
import PDFKit
import AppKit

/// Converts image(s) into a new PDF, or appends them as new pages onto an
/// existing PDF — the native replacement for the old append_image_to_pdf.py
/// script.
///
/// Bug fix: that script overwrote its source PDF in place
/// (`writer.write(str(pdf_path))`). This runner makes that impossible by
/// construction — `existingPDFURL` and `outputURL` are separate parameters,
/// and the initializer throws if they'd resolve to the same file, so there
/// is no "in place" mode to reach for.
final class ImageToPDFRunner: JobRunner, @unchecked Sendable {
    private let imageURLs: [URL]
    private let existingPDFURL: URL?
    private let outputURL: URL
    private var cancelled = false

    /// - Parameters:
    ///   - imageURLs: one or more images to add as pages, in order.
    ///   - existingPDFURL: an existing PDF to append the image pages to, or
    ///     nil to create a brand-new PDF from just the images.
    ///   - outputURL: where the result is written. Must differ from
    ///     `existingPDFURL`.
    init(imageURLs: [URL], existingPDFURL: URL?, outputURL: URL) throws {
        if let existingPDFURL, existingPDFURL.standardizedFileURL == outputURL.standardizedFileURL {
            throw PDFConvertError.outputMustDifferFromInput
        }
        self.imageURLs = imageURLs
        self.existingPDFURL = existingPDFURL
        self.outputURL = outputURL
    }

    func run(job: Job, progress: @escaping @Sendable (Double) -> Void) async throws {
        if cancelled { throw CancellationError() }
        guard !imageURLs.isEmpty else { throw PDFConvertError.invalidPageRange }

        let output: PDFDocument
        if let existingPDFURL {
            guard let existing = PDFDocument(url: existingPDFURL) else {
                throw PDFConvertError.unreadablePDF(existingPDFURL)
            }
            output = existing
        } else {
            output = PDFDocument()
        }

        for imageURL in imageURLs {
            if cancelled { throw CancellationError() }
            guard let image = NSImage(contentsOf: imageURL), let page = PDFPage(image: image) else {
                throw PDFConvertError.unreadableImage(imageURL)
            }
            output.insert(page, at: output.pageCount)
        }

        guard output.write(to: outputURL) else { throw PDFConvertError.writeFailed }
        if cancelled { throw CancellationError() }
        progress(1)
    }

    func cancel() {
        cancelled = true
    }
}
