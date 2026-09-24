import XCTest
import PDFKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
@testable import ihatefiles

final class PDFConvertersTests: XCTestCase {
    private var workDir: URL!

    override func setUpWithError() throws {
        workDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: workDir)
    }

    // MARK: - Fixtures

    private func makeSolidCGImage(width: Int = 40, height: Int = 40) -> CGImage {
        let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        )!
        context.setFillColor(red: 0.3, green: 0.5, blue: 0.7, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()!
    }

    private func makeNoisyCGImage(width: Int = 300, height: Int = 300) -> CGImage {
        let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        )!
        for _ in 0..<6000 {
            let x = Int.random(in: 0..<width)
            let y = Int.random(in: 0..<height)
            context.setFillColor(red: .random(in: 0...1), green: .random(in: 0...1), blue: .random(in: 0...1), alpha: 1)
            context.fill(CGRect(x: x, y: y, width: 1, height: 1))
        }
        return context.makeImage()!
    }

    /// Builds a PDF with `pageCount` solid-color pages and writes it to a new temp file.
    private func makePDF(pageCount: Int, name: String = UUID().uuidString) throws -> URL {
        let doc = PDFDocument()
        for _ in 0..<pageCount {
            let image = NSImage(cgImage: makeSolidCGImage(), size: NSSize(width: 40, height: 40))
            guard let page = PDFPage(image: image) else { throw XCTSkip("could not build PDFPage") }
            doc.insert(page, at: doc.pageCount)
        }
        let url = workDir.appendingPathComponent("\(name).pdf")
        XCTAssertTrue(doc.write(to: url))
        return url
    }

    /// Builds a one-page PDF from a large noisy image, so JPEG re-compression
    /// at different qualities actually produces different file sizes.
    private func makeNoisyImagePDF() throws -> URL {
        let doc = PDFDocument()
        let image = NSImage(cgImage: makeNoisyCGImage(), size: NSSize(width: 300, height: 300))
        guard let page = PDFPage(image: image) else { throw XCTSkip("could not build PDFPage") }
        doc.insert(page, at: 0)
        let url = workDir.appendingPathComponent("noisy.pdf")
        XCTAssertTrue(doc.write(to: url))
        return url
    }

    private func makePNGFile(name: String = "image") throws -> URL {
        let url = workDir.appendingPathComponent("\(name).png")
        let image = makeSolidCGImage(width: 30, height: 30)
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw XCTSkip("could not create image destination")
        }
        CGImageDestinationAddImage(destination, image, nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        return url
    }

    private func job(_ kind: JobKind) -> Job { Job(kind: kind, input: "test") }

    // MARK: - Merge

    func testMergeCombinesPageCountsInOrder() async throws {
        let a = try makePDF(pageCount: 1, name: "a")
        let b = try makePDF(pageCount: 2, name: "b")
        let output = workDir.appendingPathComponent("merged.pdf")

        try await PDFMergeRunner(inputURLs: [a, b], outputURL: output).run(job: job(.pdfMerge)) { _ in }

        let result = try XCTUnwrap(PDFDocument(url: output))
        XCTAssertEqual(result.pageCount, 3)
    }

    func testMergeRequiresAtLeastTwoInputs() async throws {
        let a = try makePDF(pageCount: 1, name: "a")
        let output = workDir.appendingPathComponent("merged.pdf")
        do {
            try await PDFMergeRunner(inputURLs: [a], outputURL: output).run(job: job(.pdfMerge)) { _ in }
            XCTFail("expected tooFewInputs")
        } catch PDFConvertError.tooFewInputs {
            // expected
        }
    }

    // MARK: - Split

    func testSplitProducesCorrectPageCounts() async throws {
        let source = try makePDF(pageCount: 5)
        let part1 = workDir.appendingPathComponent("part1.pdf")
        let part2 = workDir.appendingPathComponent("part2.pdf")

        try await PDFSplitRunner(inputURL: source, splitAfterPage: 2, firstOutputURL: part1, secondOutputURL: part2)
            .run(job: job(.pdfSplit)) { _ in }

        XCTAssertEqual(PDFDocument(url: part1)?.pageCount, 2)
        XCTAssertEqual(PDFDocument(url: part2)?.pageCount, 3)
    }

    func testSplitRejectsOutOfRangePoint() async throws {
        let source = try makePDF(pageCount: 3)
        let part1 = workDir.appendingPathComponent("part1.pdf")
        let part2 = workDir.appendingPathComponent("part2.pdf")

        do {
            try await PDFSplitRunner(inputURL: source, splitAfterPage: 3, firstOutputURL: part1, secondOutputURL: part2)
                .run(job: job(.pdfSplit)) { _ in }
            XCTFail("expected invalidPageRange")
        } catch PDFConvertError.invalidPageRange {
            // expected
        }
    }

    // MARK: - Rotate / Extract

    func testRotateChangesEveryPageRotation() async throws {
        let source = try makePDF(pageCount: 2)
        let output = workDir.appendingPathComponent("rotated.pdf")

        try await PDFPageOpsRunner(inputURL: source, outputURL: output, operation: .rotate(degrees: 90))
            .run(job: job(.pdfRotate)) { _ in }

        let result = try XCTUnwrap(PDFDocument(url: output))
        for i in 0..<result.pageCount {
            XCTAssertEqual(result.page(at: i)?.rotation, 90)
        }
    }

    func testExtractProducesOnlyRequestedRange() async throws {
        let source = try makePDF(pageCount: 5)
        let output = workDir.appendingPathComponent("extracted.pdf")

        try await PDFPageOpsRunner(inputURL: source, outputURL: output, operation: .extract(range: 2...4))
            .run(job: job(.pdfExtract)) { _ in }

        XCTAssertEqual(PDFDocument(url: output)?.pageCount, 3)
    }

    func testExtractRejectsOutOfRangeRange() async throws {
        let source = try makePDF(pageCount: 3)
        let output = workDir.appendingPathComponent("extracted.pdf")

        do {
            try await PDFPageOpsRunner(inputURL: source, outputURL: output, operation: .extract(range: 2...5))
                .run(job: job(.pdfExtract)) { _ in }
            XCTFail("expected invalidPageRange")
        } catch PDFConvertError.invalidPageRange {
            // expected
        }
    }

    // MARK: - Compress

    func testLowerCompressionQualityProducesSmallerFile() async throws {
        let source = try makeNoisyImagePDF()

        let highOutput = workDir.appendingPathComponent("high.pdf")
        try await PDFCompressRunner(inputURL: source, outputURL: highOutput, quality: 0.9)
            .run(job: job(.pdfCompress)) { _ in }

        let lowOutput = workDir.appendingPathComponent("low.pdf")
        try await PDFCompressRunner(inputURL: source, outputURL: lowOutput, quality: 0.1)
            .run(job: job(.pdfCompress)) { _ in }

        let highSize = try FileManager.default.attributesOfItem(atPath: highOutput.path)[.size] as! Int
        let lowSize = try FileManager.default.attributesOfItem(atPath: lowOutput.path)[.size] as! Int
        XCTAssertLessThan(lowSize, highSize, "lower quality should produce a smaller file on a noisy source")
    }

    func testCompressPreservesPageCount() async throws {
        let source = try makePDF(pageCount: 3)
        let output = workDir.appendingPathComponent("compressed.pdf")

        try await PDFCompressRunner(inputURL: source, outputURL: output, quality: 0.5)
            .run(job: job(.pdfCompress)) { _ in }

        XCTAssertEqual(PDFDocument(url: output)?.pageCount, 3)
    }

    // MARK: - Image to PDF

    func testImageToPDFCreatesNewOnePageDocumentWithNoExistingPDF() async throws {
        let image = try makePNGFile()
        let output = workDir.appendingPathComponent("images.pdf")

        let runner = try ImageToPDFRunner(imageURLs: [image], existingPDFURL: nil, outputURL: output)
        try await runner.run(job: job(.pdfImageToPDF)) { _ in }

        XCTAssertEqual(PDFDocument(url: output)?.pageCount, 1)
    }

    func testImageToPDFAppendsWithoutOverwritingSource() async throws {
        let existing = try makePDF(pageCount: 2, name: "existing")
        let existingDataBefore = try Data(contentsOf: existing)
        let image = try makePNGFile()
        let output = workDir.appendingPathComponent("existing-with-image.pdf")

        let runner = try ImageToPDFRunner(imageURLs: [image], existingPDFURL: existing, outputURL: output)
        try await runner.run(job: job(.pdfImageToPDF)) { _ in }

        // The new file has the appended page...
        XCTAssertEqual(PDFDocument(url: output)?.pageCount, 3)
        // ...and the original source file on disk is byte-for-byte unchanged.
        let existingDataAfter = try Data(contentsOf: existing)
        XCTAssertEqual(existingDataBefore, existingDataAfter, "source PDF must not be modified")
        XCTAssertEqual(PDFDocument(url: existing)?.pageCount, 2)
    }

    func testImageToPDFInitThrowsWhenOutputEqualsExistingInput() throws {
        let existing = try makePDF(pageCount: 1, name: "same")
        let image = try makePNGFile()

        XCTAssertThrowsError(
            try ImageToPDFRunner(imageURLs: [image], existingPDFURL: existing, outputURL: existing)
        ) { error in
            guard case PDFConvertError.outputMustDifferFromInput = error else {
                XCTFail("expected outputMustDifferFromInput, got \(error)")
                return
            }
        }
    }
}
