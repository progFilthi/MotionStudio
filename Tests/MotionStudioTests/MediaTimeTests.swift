import XCTest
@testable import MotionStudio

/// Tests for rational time: validation, comparison, arithmetic,
/// conversion, and frame snapping.
final class MediaTimeTests: XCTestCase {
    // MARK: Validation

    func testRejectsNonPositiveTimescale() {
        XCTAssertThrowsError(try MediaTime(value: 1, timescale: 0))
        XCTAssertThrowsError(try MediaTime(value: 1, timescale: -600))
    }

    func testDecodingRejectsNonPositiveTimescale() throws {
        let json = Data(#"{"value": 1, "timescale": 0}"#.utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(MediaTime.self, from: json))
    }

    // MARK: Equality and comparison

    func testEqualityAcrossTimescales() {
        XCTAssertEqual(try! MediaTime(value: 1, timescale: 2), try! MediaTime(value: 2, timescale: 4))
        XCTAssertEqual(try! MediaTime(value: 2, timescale: 4), try! MediaTime(value: 1, timescale: 2))
        XCTAssertNotEqual(try! MediaTime(value: 1, timescale: 2), try! MediaTime(value: 1, timescale: 3))
        XCTAssertEqual(MediaTime.zero, try! MediaTime(value: 0, timescale: 1))
    }

    func testHashMatchesEquality() throws {
        let a = try MediaTime(value: 1, timescale: 2)
        let b = try MediaTime(value: 2, timescale: 4)
        var hasherA = Hasher()
        var hasherB = Hasher()
        hasherA.combine(a)
        hasherB.combine(b)
        XCTAssertEqual(hasherA.finalize(), hasherB.finalize())
    }

    func testOrdering() {
        let third = try! MediaTime(value: 1, timescale: 3)
        let half = try! MediaTime(value: 1, timescale: 2)
        XCTAssertLessThan(third, half)
        XCTAssertGreaterThan(half, third)
        XCTAssertLessThan(MediaTime.exact(-1, over: 2), .zero)
        XCTAssertEqual(MediaTime.exact(1, over: 2), half)
    }

    // MARK: Arithmetic

    func testAdditionAcrossTimescales() {
        let sum = MediaTime.exact(1, over: 2) + MediaTime.exact(1, over: 4)
        XCTAssertEqual(sum, MediaTime.exact(3, over: 4))
    }

    func testSubtraction() {
        let difference = MediaTime.exact(1, over: 2) - MediaTime.exact(1, over: 4)
        XCTAssertEqual(difference, MediaTime.exact(1, over: 4))
    }

    func testClamping() {
        let clamped = MediaTime.exact(10, over: 1).clamped(
            to: MediaTime.exact(0, over: 1)...MediaTime.exact(5, over: 1)
        )
        XCTAssertEqual(clamped, MediaTime.exact(5, over: 1))
    }

    // MARK: Conversion

    func testExactConversionToMultipleTimescale() throws {
        let original = try MediaTime(value: 1, timescale: 2)
        let converted = original.converted(toTimescale: 6, rounding: .nearestAwayFromZero)
        XCTAssertEqual(converted, MediaTime.exact(3, over: 6))
        XCTAssertEqual(converted.timescale, 6)
    }

    func testNearestRounding() throws {
        // 1/3 at timescale 2 rounds to 1/2 (0.333 → 0.5).
        let converted = try MediaTime(value: 1, timescale: 3)
            .converted(toTimescale: 2, rounding: .nearestAwayFromZero)
        XCTAssertEqual(converted, MediaTime.exact(1, over: 2))
    }

    func testTowardZeroRounding() throws {
        // 2/3 at timescale 3 truncates to 2/3 at the coarser scale:
        // exact here, so test a lossy case: 2/3 (0.667) at timescale 2.
        let converted = try MediaTime(value: 2, timescale: 3)
            .converted(toTimescale: 1, rounding: .towardZero)
        XCTAssertEqual(converted, MediaTime.exact(0, over: 1))
    }

    // MARK: Frame snapping

    func testSnapsToNearestFrame() {
        let rate = FrameRate.fps30
        // 0.6 s is exactly frame 18.
        let exact = MediaTime.fromSeconds(0.6).roundedToFrame(of: rate, rounding: .nearestAwayFromZero)
        XCTAssertEqual(exact, MediaTime.exact(18, over: 30))

        // 0.607 s (18.21 frames) stays on frame 18.
        let near = MediaTime.fromSeconds(0.607).roundedToFrame(of: rate, rounding: .nearestAwayFromZero)
        XCTAssertEqual(near, MediaTime.exact(18, over: 30))

        // 0.634 s (19.02 frames) moves to frame 19.
        let next = MediaTime.fromSeconds(0.634).roundedToFrame(of: rate, rounding: .nearestAwayFromZero)
        XCTAssertEqual(next, MediaTime.exact(19, over: 30))
    }

    func testSnapsFractionalFrameRateExactly() {
        // 1 second at NTSC 29.97 is frame 29.97 → snaps to frame 30,
        // which is 30 * 1001 / 30000 s — exactly representable.
        let snapped = MediaTime.fromSeconds(1).roundedToFrame(
            of: .ntsc29_97,
            rounding: .nearestAwayFromZero
        )
        XCTAssertEqual(snapped, MediaTime.exact(30 * 1001, over: 30000))
    }

    // MARK: Derived values

    func testFromSeconds() {
        XCTAssertEqual(MediaTime.fromSeconds(0.5), MediaTime.exact(300, over: 600))
        XCTAssertEqual(MediaTime.fromSeconds(-1), .zero)
        XCTAssertEqual(MediaTime.fromSeconds(.nan), .zero)
        XCTAssertEqual(MediaTime.fromSeconds(.infinity), .zero)
    }

    func testSecondsMatchesComponents() {
        XCTAssertEqual(MediaTime.exact(3001, over: 1001).seconds, 3001.0 / 1001.0, accuracy: 1e-12)
    }
}
