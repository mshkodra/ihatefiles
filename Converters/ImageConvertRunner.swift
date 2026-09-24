import Foundation
import ImageIO
import CoreGraphics
import UniformTypeIdentifiers

/// Native image operations via ImageIO/CoreGraphics — no bundled binary, no
/// Process spawning. A conversion (JobKind.imageConvert), not a download —
/// JobManager runs it immediately, uncapped.
///
/// ImageIO's calls are synchronous with no fine-grained progress signal
/// (unlike ffmpeg's -progress pipe or yt-dlp's percentage lines), so progress
/// jumps 0 -> 1 on completion. That's an intentional exception to "real
/// progress," not a bug — see Converters/CLAUDE.md.
final class ImageConvertRunner: JobRunner, @unchecked Sendable {
    enum Operation {
        /// Re-encode to `format`, flattening any alpha onto `background` (JPEG has no alpha channel).
        case convert(format: UTType, background: CGColor)
        /// Scale to fit within `maxDimension` on the longer side, preserving aspect ratio.
        case resize(maxDimension: CGFloat)
        /// Re-encode as JPEG at `quality` (0...1).
        case compress(quality: CGFloat)
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

        guard let source = CGImageSourceCreateWithURL(inputURL as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw ImageConvertError.unreadableImage
        }

        switch operation {
        case let .convert(format, background):
            try Self.write(flattening(image, onto: background), to: outputURL, type: format, quality: nil)
        case let .resize(maxDimension):
            let resized = try Self.resize(image, maxDimension: maxDimension)
            let type = UTType(filenameExtension: outputURL.pathExtension) ?? .png
            try Self.write(resized, to: outputURL, type: type, quality: nil)
        case let .compress(quality):
            try Self.write(image, to: outputURL, type: .jpeg, quality: quality)
        }

        if cancelled { throw CancellationError() }
        progress(1)
    }

    func cancel() {
        cancelled = true
    }

    /// JPEG has no alpha channel. Rather than silently inheriting PIL's
    /// black-composite default (`Image.convert("RGB")`), flatten explicitly
    /// onto the caller-chosen background — white by default, since that
    /// matches user expectations for "convert to JPEG" better than black.
    private func flattening(_ image: CGImage, onto background: CGColor) -> CGImage {
        let width = image.width
        let height = image.height
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else {
            return image
        }
        context.setFillColor(background)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage() ?? image
    }

    private static func resize(_ image: CGImage, maxDimension: CGFloat) throws -> CGImage {
        let width = CGFloat(image.width)
        let height = CGFloat(image.height)
        let scale = min(maxDimension / width, maxDimension / height, 1)
        let targetWidth = max(1, Int((width * scale).rounded()))
        let targetHeight = max(1, Int((height * scale).rounded()))

        guard let context = CGContext(
            data: nil,
            width: targetWidth,
            height: targetHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw ImageConvertError.resizeFailed
        }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))
        guard let resized = context.makeImage() else { throw ImageConvertError.resizeFailed }
        return resized
    }

    private static func write(_ image: CGImage, to url: URL, type: UTType, quality: CGFloat?) throws {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, 1, nil) else {
            throw ImageConvertError.writeFailed
        }
        var options: [CFString: Any] = [:]
        if let quality {
            options[kCGImageDestinationLossyCompressionQuality] = quality
        }
        CGImageDestinationAddImage(destination, image, options as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw ImageConvertError.writeFailed
        }
    }
}

enum ImageConvertError: Error {
    case unreadableImage
    case resizeFailed
    case writeFailed
}
