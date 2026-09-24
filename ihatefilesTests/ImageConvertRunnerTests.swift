import XCTest
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
@testable import ihatefiles

final class ImageConvertRunnerTests: XCTestCase {
    private var workDir: URL!

    override func setUpWithError() throws {
        workDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: workDir)
    }

    // MARK: - Fixtures

    /// A small RGBA image, fully transparent, for testing alpha flattening.
    private func makeTransparentPNG(width: Int = 20, height: Int = 20) throws -> URL {
        let url = workDir.appendingPathComponent("transparent.png")
        guard let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { throw XCTSkip("could not create CGContext") }
        context.clear(CGRect(x: 0, y: 0, width: width, height: height))
        let image = context.makeImage()!

        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw XCTSkip("could not create image destination")
        }
        CGImageDestinationAddImage(destination, image, nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        return url
    }

    /// A larger image with per-pixel noise, so JPEG compression quality actually
    /// produces different file sizes (a flat-color image compresses identically
    /// regardless of quality, which wouldn't exercise the setting at all).
    private func makeNoisyJPEG(width: Int = 256, height: Int = 256) throws -> URL {
        let url = workDir.appendingPathComponent("noisy.jpg")
        guard let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else { throw XCTSkip("could not create CGContext") }
        for _ in 0..<4000 {
            let x = Int.random(in: 0..<width)
            let y = Int.random(in: 0..<height)
            context.setFillColor(red: .random(in: 0...1), green: .random(in: 0...1), blue: .random(in: 0...1), alpha: 1)
            context.fill(CGRect(x: x, y: y, width: 1, height: 1))
        }
        let image = context.makeImage()!
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw XCTSkip("could not create image destination")
        }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 1.0] as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        return url
    }

    private func makeSolidPNG(width: Int, height: Int) throws -> URL {
        let url = workDir.appendingPathComponent("solid-\(width)x\(height).png")
        guard let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else { throw XCTSkip("could not create CGContext") }
        context.setFillColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let image = context.makeImage()!
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw XCTSkip("could not create image destination")
        }
        CGImageDestinationAddImage(destination, image, nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        return url
    }

    private func loadCGImage(_ url: URL) throws -> CGImage {
        let source = try XCTUnwrap(CGImageSourceCreateWithURL(url as CFURL, nil))
        return try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
    }

    private func cornerPixelIsOpaqueWhite(_ image: CGImage) -> Bool {
        guard let data = image.dataProvider?.data, let ptr = CFDataGetBytePtr(data) else { return false }
        // First pixel, assuming 4 bytes/pixel RGBA-ish layout (exact channel order
        // doesn't matter here since we only assert all three color channels are ~max).
        let bytesPerPixel = image.bitsPerPixel / 8
        guard bytesPerPixel >= 3 else { return false }
        let r = ptr[0], g = ptr[1], b = ptr[2]
        return r > 250 && g > 250 && b > 250
    }

    // MARK: - Tests

    func testConvertFlattensTransparencyToWhiteBackground() async throws {
        let input = try makeTransparentPNG()
        let output = workDir.appendingPathComponent("flattened.jpg")
        let white = CGColor(red: 1, green: 1, blue: 1, alpha: 1)
        let runner = ImageConvertRunner(inputURL: input, outputURL: output, operation: .convert(format: .jpeg, background: white))

        try await runner.run(job: Job(kind: .imageConvert, input: "test")) { _ in }

        XCTAssertTrue(FileManager.default.fileExists(atPath: output.path))
        let result = try loadCGImage(output)
        // ImageIO's JPEG decoder may report .none (tightly packed) or .noneSkipLast
        // (a padding byte present but unused) — both mean "no real alpha channel."
        XCTAssertTrue(
            result.alphaInfo == .none || result.alphaInfo == .noneSkipLast || result.alphaInfo == .noneSkipFirst,
            "JPEG output should have no meaningful alpha channel, got \(result.alphaInfo)"
        )
        XCTAssertTrue(cornerPixelIsOpaqueWhite(result), "transparent area should flatten to white, not black")
    }

    func testResizeScalesDownPreservingAspectRatio() async throws {
        let input = try makeSolidPNG(width: 200, height: 100)
        let output = workDir.appendingPathComponent("resized.png")
        let runner = ImageConvertRunner(inputURL: input, outputURL: output, operation: .resize(maxDimension: 100))

        try await runner.run(job: Job(kind: .imageConvert, input: "test")) { _ in }

        let result = try loadCGImage(output)
        XCTAssertEqual(result.width, 100)
        XCTAssertEqual(result.height, 50, "aspect ratio (2:1) should be preserved")
    }

    func testResizeNeverUpscales() async throws {
        let input = try makeSolidPNG(width: 50, height: 50)
        let output = workDir.appendingPathComponent("not-upscaled.png")
        let runner = ImageConvertRunner(inputURL: input, outputURL: output, operation: .resize(maxDimension: 1000))

        try await runner.run(job: Job(kind: .imageConvert, input: "test")) { _ in }

        let result = try loadCGImage(output)
        XCTAssertEqual(result.width, 50)
        XCTAssertEqual(result.height, 50)
    }

    func testLowerCompressionQualityProducesSmallerFile() async throws {
        let input = try makeNoisyJPEG()

        let highQualityOutput = workDir.appendingPathComponent("high.jpg")
        try await ImageConvertRunner(inputURL: input, outputURL: highQualityOutput, operation: .compress(quality: 0.9))
            .run(job: Job(kind: .imageConvert, input: "test")) { _ in }

        let lowQualityOutput = workDir.appendingPathComponent("low.jpg")
        try await ImageConvertRunner(inputURL: input, outputURL: lowQualityOutput, operation: .compress(quality: 0.1))
            .run(job: Job(kind: .imageConvert, input: "test")) { _ in }

        let highSize = try FileManager.default.attributesOfItem(atPath: highQualityOutput.path)[.size] as! Int
        let lowSize = try FileManager.default.attributesOfItem(atPath: lowQualityOutput.path)[.size] as! Int
        XCTAssertLessThan(lowSize, highSize, "lower quality setting should produce a smaller file on a noisy source image")
    }

    func testProgressReportsCompletionOnSuccess() async throws {
        let input = try makeSolidPNG(width: 40, height: 40)
        let output = workDir.appendingPathComponent("progress.png")
        let runner = ImageConvertRunner(inputURL: input, outputURL: output, operation: .resize(maxDimension: 20))

        var reported: [Double] = []
        try await runner.run(job: Job(kind: .imageConvert, input: "test")) { reported.append($0) }

        XCTAssertEqual(reported, [1.0], "native ImageIO ops have no fine-grained progress; should jump straight to 1.0")
    }

    func testCancelBeforeRunThrows() async throws {
        let input = try makeSolidPNG(width: 10, height: 10)
        let output = workDir.appendingPathComponent("cancelled.png")
        let runner = ImageConvertRunner(inputURL: input, outputURL: output, operation: .resize(maxDimension: 5))
        runner.cancel()

        do {
            try await runner.run(job: Job(kind: .imageConvert, input: "test")) { _ in }
            XCTFail("expected CancellationError")
        } catch is CancellationError {
            // expected
        }
    }
}
