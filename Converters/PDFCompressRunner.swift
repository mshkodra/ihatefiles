import Foundation
import PDFKit
import CoreGraphics
import AppKit
import UniformTypeIdentifiers

/// Reduces PDF file size by re-rendering each page to a JPEG at the given
/// quality and rebuilding the document from those images.
///
/// PDFKit has no "recompress embedded images in place" API, so this is the
/// pragmatic approach: it shrinks any PDF (not just image-heavy ones) at the
/// cost of pages becoming raster instead of vector/text. That's an
/// intentional tradeoff for a "make this smaller" tool, not meant for
/// text-searchable archival compression — see Converters/CLAUDE.md.
final class PDFCompressRunner: JobRunner, @unchecked Sendable {
    private let inputURL: URL
    private let outputURL: URL
    private let quality: CGFloat
    private var cancelled = false

    /// Modest raster resolution multiplier — enough to stay legible without
    /// ballooning back up toward the original size.
    private let renderScale: CGFloat = 1.5

    init(inputURL: URL, outputURL: URL, quality: CGFloat) {
        self.inputURL = inputURL
        self.outputURL = outputURL
        self.quality = quality
    }

    func run(job: Job, progress: @escaping @Sendable (Double) -> Void) async throws {
        if cancelled { throw CancellationError() }
        guard let source = PDFDocument(url: inputURL) else { throw PDFConvertError.unreadablePDF(inputURL) }
        guard source.pageCount > 0 else { throw PDFConvertError.invalidPageRange }

        let output = PDFDocument()
        for pageIndex in 0..<source.pageCount {
            if cancelled { throw CancellationError() }
            guard let page = source.page(at: pageIndex) else { continue }
            let rendered = try render(page: page)
            guard let jpegData = Self.jpegData(from: rendered, quality: quality),
                  let image = NSImage(data: jpegData),
                  let newPage = PDFPage(image: image) else {
                throw PDFConvertError.writeFailed
            }
            output.insert(newPage, at: output.pageCount)
            progress(Double(pageIndex + 1) / Double(source.pageCount) * 0.9)
        }

        guard output.write(to: outputURL) else { throw PDFConvertError.writeFailed }
        if cancelled { throw CancellationError() }
        progress(1)
    }

    func cancel() {
        cancelled = true
    }

    private func render(page: PDFPage) throws -> CGImage {
        let bounds = page.bounds(for: .mediaBox)
        let pixelWidth = max(1, Int(bounds.width * renderScale))
        let pixelHeight = max(1, Int(bounds.height * renderScale))

        guard let context = CGContext(
            data: nil,
            width: pixelWidth,
            height: pixelHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else { throw PDFConvertError.writeFailed }

        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))
        context.scaleBy(x: renderScale, y: renderScale)
        page.draw(with: .mediaBox, to: context)

        guard let image = context.makeImage() else { throw PDFConvertError.writeFailed }
        return image
    }

    private static func jpegData(from image: CGImage, quality: CGFloat) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }
}
