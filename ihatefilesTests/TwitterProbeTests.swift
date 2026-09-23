import XCTest
@testable import ihatefiles

final class TwitterFormatParserTests: XCTestCase {
    private let fixtureJSON = """
    {"formats": [
        {"format_id": "audio-only", "vcodec": "none", "acodec": "mp4a.40.2", "ext": "m4a"},
        {"format_id": "hls-2176", "vcodec": "h264", "acodec": "aac", "tbr": 2176.0, "ext": "mp4", "width": 1280, "height": 720, "filesize": 5000000},
        {"format_id": "hls-832", "vcodec": "h264", "acodec": "aac", "tbr": 832.0, "ext": "mp4", "width": 640, "height": 360, "filesize_approx": 2000000},
        {"format_id": "hls-256", "vcodec": "h264", "acodec": "aac", "tbr": 256.0, "ext": "mp4", "format_note": "240p"}
    ]}
    """

    func testFiltersOutAudioOnlyFormats() {
        let formats = TwitterFormatParser.parseFormats(fromJSON: fixtureJSON)
        XCTAssertFalse(formats.contains { $0.formatId == "audio-only" })
    }

    func testSortsByBitrateDescending() {
        let formats = TwitterFormatParser.parseFormats(fromJSON: fixtureJSON)
        XCTAssertEqual(formats.map(\.formatId), ["hls-2176", "hls-832", "hls-256"])
    }

    func testPrefersFormatNoteOverDimensions() {
        let formats = TwitterFormatParser.parseFormats(fromJSON: fixtureJSON)
        let lowRes = formats.first { $0.formatId == "hls-256" }
        XCTAssertEqual(lowRes?.note, "240p")
    }

    func testFallsBackToDimensionsWhenNoFormatNote() {
        let formats = TwitterFormatParser.parseFormats(fromJSON: fixtureJSON)
        let hd = formats.first { $0.formatId == "hls-2176" }
        XCTAssertEqual(hd?.note, "1280x720")
    }

    func testPrefersFilesizeOverFilesizeApprox() {
        let formats = TwitterFormatParser.parseFormats(fromJSON: fixtureJSON)
        let hd = formats.first { $0.formatId == "hls-2176" }
        XCTAssertEqual(hd?.filesizeBytes, 5_000_000)
    }

    func testFallsBackToFilesizeApprox() {
        let formats = TwitterFormatParser.parseFormats(fromJSON: fixtureJSON)
        let mid = formats.first { $0.formatId == "hls-832" }
        XCTAssertEqual(mid?.filesizeBytes, 2_000_000)
    }

    func testEmptyFormatsArrayReturnsEmpty() {
        XCTAssertEqual(TwitterFormatParser.parseFormats(fromJSON: #"{"formats": []}"#), [])
    }

    func testMissingFormatsKeyReturnsEmpty() {
        XCTAssertEqual(TwitterFormatParser.parseFormats(fromJSON: #"{"id": "12345"}"#), [])
    }

    func testMalformedJSONReturnsEmpty() {
        XCTAssertEqual(TwitterFormatParser.parseFormats(fromJSON: "not json"), [])
    }
}

final class TwitterURLDetectorTests: XCTestCase {
    func testMatchesTwitterDotCom() {
        XCTAssertTrue(TwitterURLDetector.isTwitterURL("https://twitter.com/user/status/12345"))
    }

    func testMatchesXDotCom() {
        XCTAssertTrue(TwitterURLDetector.isTwitterURL("https://x.com/user/status/12345"))
    }

    func testMatchesSubdomain() {
        XCTAssertTrue(TwitterURLDetector.isTwitterURL("https://mobile.twitter.com/user/status/12345"))
    }

    func testRejectsUnrelatedDomainEndingInXDotCom() {
        // A plain suffix check on "x.com" would wrongly match "foobarx.com".
        XCTAssertFalse(TwitterURLDetector.isTwitterURL("https://foobarx.com/video"))
    }

    func testRejectsYouTube() {
        XCTAssertFalse(TwitterURLDetector.isTwitterURL("https://www.youtube.com/watch?v=abc123"))
    }

    func testRejectsEmptyString() {
        XCTAssertFalse(TwitterURLDetector.isTwitterURL(""))
    }
}
