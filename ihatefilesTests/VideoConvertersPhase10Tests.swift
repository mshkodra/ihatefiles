import XCTest
@testable import ihatefiles

final class VideoDimensionsProbeTests: XCTestCase {
    func testParsesStandardVideoStreamLine() {
        let output = "Stream #0:0(und): Video: h264 (High), yuv420p(tv, bt709), 1920x1080 [SAR 1:1 DAR 16:9], 30 fps, 30 tbr, 15360 tbn"
        let dimensions = VideoDimensionsProbe.parseDimensions(from: output)
        XCTAssertEqual(dimensions?.width, 1920)
        XCTAssertEqual(dimensions?.height, 1080)
    }

    func testMissingVideoStreamReturnsNil() {
        XCTAssertNil(VideoDimensionsProbe.parseDimensions(from: "no video stream info here"))
    }

    func testMalformedDimensionsReturnNil() {
        XCTAssertNil(VideoDimensionsProbe.parseDimensions(from: "Video: h264, yuv420p, unknown resolution"))
    }

    func testPicksDimensionsFromVideoLineNotEarlierNoise() {
        let output = "Duration: 00:01:00.00, bitrate: 5000 kb/s\nStream #0:0: Video: h264, yuv420p, 640x480, 30 fps"
        let dimensions = VideoDimensionsProbe.parseDimensions(from: output)
        XCTAssertEqual(dimensions?.width, 640)
        XCTAssertEqual(dimensions?.height, 480)
    }
}

final class VideoOverlayGeometryTests: XCTestCase {
    func testTopRightPlacementAt20PercentWidth() {
        let geometry = VideoOverlayRunner.geometry(
            screenWidth: 1000, screenHeight: 600,
            webcamWidth: 640, webcamHeight: 480
        )
        XCTAssertEqual(geometry.overlayWidth, 200) // 20% of 1000
        XCTAssertEqual(geometry.overlayHeight, 150) // 200 * (480/640), webcam's own aspect ratio
        XCTAssertEqual(geometry.x, 780) // 1000 - 200 - 20 => top-RIGHT, not top-left
        XCTAssertEqual(geometry.y, 20)
    }

    func testPreservesWebcamAspectRatioIndependentOfScreenAspectRatio() {
        // A portrait webcam (9:16) over a widescreen (16:9) recording — the
        // overlay's height should follow the webcam's own ratio, not the screen's.
        let geometry = VideoOverlayRunner.geometry(
            screenWidth: 1920, screenHeight: 1080,
            webcamWidth: 1080, webcamHeight: 1920
        )
        XCTAssertEqual(geometry.overlayWidth, 384) // 20% of 1920
        XCTAssertEqual(geometry.overlayHeight, 682) // 384 * (1920/1080), rounded down
        XCTAssertEqual(geometry.x, 1516) // 1920 - 384 - 20
    }
}

final class VideoConcatRunnerTests: XCTestCase {
    func testBuildFileListFormatsAndEscapesQuotes() {
        let list = VideoConcatRunner.buildFileList(paths: ["/a/b.mp4", "/a/it's a clip.mp4"])
        XCTAssertEqual(list, "file '/a/b.mp4'\nfile '/a/it'\\''s a clip.mp4'\n")
    }

    func testBuildFilterComplexForThreeInputs() {
        let filter = VideoConcatRunner.buildFilterComplex(inputCount: 3)
        XCTAssertEqual(filter, "[0:v:0][0:a:0][1:v:0][1:a:0][2:v:0][2:a:0]concat=n=3:v=1:a=1[outv][outa]")
    }

    func testBuildFilterComplexForTwoInputs() {
        let filter = VideoConcatRunner.buildFilterComplex(inputCount: 2)
        XCTAssertEqual(filter, "[0:v:0][0:a:0][1:v:0][1:a:0]concat=n=2:v=1:a=1[outv][outa]")
    }
}
