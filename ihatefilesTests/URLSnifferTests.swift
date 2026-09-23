import XCTest
@testable import ihatefiles

final class URLSnifferTests: XCTestCase {
    func testRoutesYouTubeWatchURLToVideo() {
        XCTAssertEqual(URLSniffer.route(for: "https://www.youtube.com/watch?v=abc123"), .youtubeVideo)
    }

    func testRoutesYoutuDotBeToVideo() {
        XCTAssertEqual(URLSniffer.route(for: "https://youtu.be/abc123"), .youtubeVideo)
    }

    func testRoutesYouTubePlaylistURLToPlaylist() {
        XCTAssertEqual(
            URLSniffer.route(for: "https://www.youtube.com/playlist?list=PL12345"),
            .youtubePlaylist
        )
    }

    func testRoutesYouTubeWatchURLWithListParamToPlaylist() {
        XCTAssertEqual(
            URLSniffer.route(for: "https://www.youtube.com/watch?v=abc123&list=PL12345"),
            .youtubePlaylist
        )
    }

    func testRoutesTwitterDotComToTwitter() {
        XCTAssertEqual(URLSniffer.route(for: "https://twitter.com/user/status/12345"), .twitter)
    }

    func testRoutesXDotComToTwitter() {
        XCTAssertEqual(URLSniffer.route(for: "https://x.com/user/status/12345"), .twitter)
    }

    func testRoutesVimeoToGeneric() {
        XCTAssertEqual(URLSniffer.route(for: "https://vimeo.com/12345678"), .generic)
    }

    func testRoutesSoundCloudToGeneric() {
        XCTAssertEqual(URLSniffer.route(for: "https://soundcloud.com/artist/track"), .generic)
    }

    func testRoutesArbitraryNonMatchingURLToGeneric() {
        XCTAssertEqual(URLSniffer.route(for: "https://example.com/video.mp4"), .generic)
    }

    func testRoutesEmptyStringToGeneric() {
        XCTAssertEqual(URLSniffer.route(for: ""), .generic)
    }

    func testDoesNotFalsePositiveOnUnrelatedDomainEndingInYoutuDotBe() {
        XCTAssertEqual(URLSniffer.route(for: "https://notyoutu.be/abc123"), .generic)
    }
}
