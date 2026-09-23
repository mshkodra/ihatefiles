import XCTest
@testable import ihatefiles

final class FfmpegProgressParserTests: XCTestCase {
    func testMidProgressBlockParsesToFraction() {
        let parser = FfmpegProgressParser(totalDuration: 100)
        XCTAssertNil(parser.ingest(line: "out_time_ms=45000000"))
        let fraction = parser.ingest(line: "progress=continue")
        XCTAssertEqual(fraction ?? -1, 0.45, accuracy: 0.0001)
    }

    func testProgressEndMapsToOne() {
        let parser = FfmpegProgressParser(totalDuration: 100)
        _ = parser.ingest(line: "out_time_ms=10000000")
        XCTAssertEqual(parser.ingest(line: "progress=end") ?? -1, 1.0, accuracy: 0.0001)
    }

    func testOutTimeUsKeyIsAlsoRecognized() {
        let parser = FfmpegProgressParser(totalDuration: 50)
        _ = parser.ingest(line: "out_time_us=25000000")
        XCTAssertEqual(parser.ingest(line: "progress=continue") ?? -1, 0.5, accuracy: 0.0001)
    }

    func testFractionIsClampedToOneWhenOutTimeExceedsDuration() {
        let parser = FfmpegProgressParser(totalDuration: 10)
        _ = parser.ingest(line: "out_time_ms=99000000")
        XCTAssertEqual(parser.ingest(line: "progress=continue") ?? -1, 1.0, accuracy: 0.0001)
    }

    func testUnrelatedKeyValueLineReturnsNil() {
        let parser = FfmpegProgressParser(totalDuration: 100)
        XCTAssertNil(parser.ingest(line: "frame=120"))
        XCTAssertNil(parser.ingest(line: "speed=1.02x"))
    }

    func testMalformedLineDoesNotCrashAndReturnsNil() {
        let parser = FfmpegProgressParser(totalDuration: 100)
        XCTAssertNil(parser.ingest(line: ""))
        XCTAssertNil(parser.ingest(line: "not a key value line"))
    }

    func testProgressContinueWithoutPriorOutTimeReturnsNil() {
        let parser = FfmpegProgressParser(totalDuration: 100)
        XCTAssertNil(parser.ingest(line: "progress=continue"))
    }

    func testZeroDurationDoesNotDivideByZero() {
        let parser = FfmpegProgressParser(totalDuration: 0)
        _ = parser.ingest(line: "out_time_ms=1000000")
        XCTAssertNil(parser.ingest(line: "progress=continue"))
    }
}

final class VideoDurationProbeTests: XCTestCase {
    func testParsesStandardDurationLine() {
        let output = "Input #0, matroska,webm, from 'in.webm':\n  Duration: 00:02:15.30, start: 0.000000, bitrate: 512 kb/s"
        XCTAssertEqual(VideoDurationProbe.parseDuration(from: output) ?? -1, 135.30, accuracy: 0.01)
    }

    func testMissingDurationReturnsNil() {
        XCTAssertNil(VideoDurationProbe.parseDuration(from: "no duration info here"))
    }

    func testMalformedDurationReturnsNil() {
        XCTAssertNil(VideoDurationProbe.parseDuration(from: "Duration: not-a-time, start: 0"))
    }
}
