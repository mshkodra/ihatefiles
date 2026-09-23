import XCTest
@testable import ihatefiles

final class YtDlpProgressParserTests: XCTestCase {
    func testMidProgressLineParsesToFraction() {
        let line = "[download]  45.2% of   10.00MiB at    1.20MiB/s ETA 00:05"
        XCTAssertEqual(YtDlpProgressParser.parseProgress(from: line) ?? -1, 0.452, accuracy: 0.0001)
    }

    func testDecimalFullProgressLineParsesToOne() {
        let line = "[download] 100.0% of   10.00MiB in 00:15"
        XCTAssertEqual(YtDlpProgressParser.parseProgress(from: line) ?? -1, 1.0, accuracy: 0.0001)
    }

    func testIntegerPercentLineParses() {
        let line = "[download] 100% of 10.00MiB in 00:15"
        XCTAssertEqual(YtDlpProgressParser.parseProgress(from: line) ?? -1, 1.0, accuracy: 0.0001)
    }

    func testMergerLineReturnsNil() {
        let line = "[Merger] Merging formats into \"video.mp4\""
        XCTAssertNil(YtDlpProgressParser.parseProgress(from: line))
    }

    func testMetadataLineReturnsNil() {
        let line = "[youtube] abc123: Downloading webpage"
        XCTAssertNil(YtDlpProgressParser.parseProgress(from: line))
    }

    func testAlreadyDownloadedLineReturnsNil() {
        let line = "[download] video.mp4 has already been downloaded"
        XCTAssertNil(YtDlpProgressParser.parseProgress(from: line))
    }
}
