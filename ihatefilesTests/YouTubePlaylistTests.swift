import XCTest
@testable import ihatefiles

final class YouTubePlaylistDetectorTests: XCTestCase {
    func testPlaylistURLIsDetected() {
        XCTAssertTrue(YouTubePlaylistDetector.isPlaylistURL(
            "https://www.youtube.com/playlist?list=PLabc123"
        ))
    }

    func testVideoWithinPlaylistIsDetected() {
        XCTAssertTrue(YouTubePlaylistDetector.isPlaylistURL(
            "https://www.youtube.com/watch?v=abc123&list=PLabc123"
        ))
    }

    func testPlainVideoURLIsNotDetected() {
        XCTAssertFalse(YouTubePlaylistDetector.isPlaylistURL(
            "https://www.youtube.com/watch?v=abc123"
        ))
    }

    func testEmptyListValueIsNotDetected() {
        XCTAssertFalse(YouTubePlaylistDetector.isPlaylistURL(
            "https://www.youtube.com/watch?v=abc123&list="
        ))
    }

    func testMalformedURLIsNotDetected() {
        XCTAssertFalse(YouTubePlaylistDetector.isPlaylistURL(""))
    }
}

final class YouTubePlaylistParserTests: XCTestCase {
    func testValidEntryLineParses() {
        let line = #"{"id": "abc123", "title": "My Video", "_type": "url"}"#
        let entry = YouTubePlaylistParser.parseEntry(fromJSONLine: line)
        XCTAssertEqual(entry, YouTubePlaylistEntry(id: "abc123", title: "My Video"))
    }

    func testMissingTitleFallsBackToId() {
        let line = #"{"id": "abc123"}"#
        let entry = YouTubePlaylistParser.parseEntry(fromJSONLine: line)
        XCTAssertEqual(entry, YouTubePlaylistEntry(id: "abc123", title: "abc123"))
    }

    func testMissingIdReturnsNil() {
        let line = #"{"title": "My Video"}"#
        XCTAssertNil(YouTubePlaylistParser.parseEntry(fromJSONLine: line))
    }

    func testMalformedJSONReturnsNil() {
        XCTAssertNil(YouTubePlaylistParser.parseEntry(fromJSONLine: "not json"))
    }

    func testEmptyLineReturnsNil() {
        XCTAssertNil(YouTubePlaylistParser.parseEntry(fromJSONLine: ""))
    }
}
