import XCTest
@testable import MotionStudio

/// Tests for rational frame rates.
final class FrameRateTests: XCTestCase {
    func testRejectsNonPositiveComponents() {
        XCTAssertThrowsError(try FrameRate(numerator: 0, denominator: 1))
        XCTAssertThrowsError(try FrameRate(numerator: 30, denominator: 0))
        XCTAssertThrowsError(try FrameRate(numerator: -30, denominator: 1))
    }

    func testDecodingRejectsInvalidComponents() throws {
        let json = Data(#"{"numerator": 30, "denominator": 0}"#.utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(FrameRate.self, from: json))
    }

    func testPreservesFractionalNTSCRate() {
        let rate = FrameRate.exact(30000, over: 1001)
        XCTAssertEqual(rate.numerator, 30000)
        XCTAssertEqual(rate.denominator, 1001)
        XCTAssertEqual(rate.framesPerSecond, 29.97, accuracy: 0.001)
    }

    func testFrameDuration() {
        // One frame of 30 fps lasts 1/30 s.
        XCTAssertEqual(FrameRate.fps30.frameDuration, MediaTime.exact(1, over: 30))
        // One frame of 30000/1001 lasts 1001/30000 s.
        XCTAssertEqual(FrameRate.ntsc29_97.frameDuration, MediaTime.exact(1001, over: 30000))
    }

    func testRecognitionMatchesCanonicalRates() {
        XCTAssertEqual(FrameRateRecognition.frameRate(approximating: 29.97), .ntsc29_97)
        XCTAssertEqual(FrameRateRecognition.frameRate(approximating: 23.976), .exact(24000, over: 1001))
        XCTAssertEqual(FrameRateRecognition.frameRate(approximating: 59.94), .ntsc59_94)
        XCTAssertEqual(FrameRateRecognition.frameRate(approximating: 30), .fps30)
        XCTAssertEqual(FrameRateRecognition.frameRate(approximating: 25), .fps25)
        XCTAssertNil(FrameRateRecognition.frameRate(approximating: 0))
        XCTAssertNil(FrameRateRecognition.frameRate(approximating: .nan))

        // Unknown fractional rate keeps thousandths fidelity.
        let odd = FrameRateRecognition.frameRate(approximating: 25.4)
        XCTAssertEqual(odd, FrameRate.exact(25400, over: 1000))
    }

    func testCodableRoundTrip() throws {
        let rate = FrameRate.ntsc29_97
        let data = try JSONEncoder().encode(rate)
        let decoded = try JSONDecoder().decode(FrameRate.self, from: data)
        XCTAssertEqual(decoded, rate)
    }
}
