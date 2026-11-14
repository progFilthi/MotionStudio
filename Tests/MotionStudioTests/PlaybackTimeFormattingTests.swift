import AVFoundation
import XCTest
@testable import MotionStudio

final class PlaybackTimeFormattingTests: XCTestCase {
    func testFormatsMinutesAndSeconds() {
        XCTAssertEqual(PlaybackTimeFormatting.format(seconds: 0), "0:00.0")
        XCTAssertEqual(PlaybackTimeFormatting.format(seconds: 4.99), "0:04.9")
        XCTAssertEqual(PlaybackTimeFormatting.format(seconds: 65.4), "1:05.4")
    }

    func testFormatsHours() {
        XCTAssertEqual(PlaybackTimeFormatting.format(seconds: 3725), "1:02:05.0")
    }

    func testHandlesInvalidAndNegativeTimes() {
        XCTAssertEqual(PlaybackTimeFormatting.format(seconds: -5), "0:00.0")
        XCTAssertEqual(PlaybackTimeFormatting.format(seconds: .nan), "0:00.0")
        XCTAssertEqual(PlaybackTimeFormatting.format(CMTime.invalid), "0:00.0")
    }
}
