import XCTest
@testable import MotionStudio

final class TimelineRulerMetricsTests: XCTestCase {
    // MARK: Labeled interval

    func testLabeledIntervalAtDefaultZoomIsOneSecond() {
        // 1 s × 120 pt/s = 120 pt ≥ 90 pt; 0.5 s falls short.
        XCTAssertEqual(
            TimelineRulerMetrics.labeledInterval(pixelsPerSecond: 120),
            1
        )
    }

    func testLabeledIntervalZoomedOutShowsMinutes() {
        // A long video zoomed out far: 60 s × 2 pt/s = 120 pt ≥ 90 pt.
        XCTAssertEqual(
            TimelineRulerMetrics.labeledInterval(pixelsPerSecond: 2),
            60
        )
    }

    func testLabeledIntervalZoomedInUsesSubSecondTicks() {
        // 0.25 s × 600 pt/s = 150 pt ≥ 90 pt; 0.1 s × 600 = 60 pt.
        XCTAssertEqual(
            TimelineRulerMetrics.labeledInterval(pixelsPerSecond: 600),
            0.25
        )
    }

    func testLabeledIntervalBeyondLadderReturnsCoarsestCandidate() {
        XCTAssertEqual(
            TimelineRulerMetrics.labeledInterval(pixelsPerSecond: 0.01),
            3600
        )
    }

    // MARK: Minor interval

    func testMinorIntervalIsOneFifthOfLabeledWhenReadable() {
        XCTAssertEqual(
            TimelineRulerMetrics.minorInterval(labeled: 5, pixelsPerSecond: 20),
            1
        )
    }

    func testMinorIntervalNilBelowOneSecondLabeled() {
        XCTAssertNil(
            TimelineRulerMetrics.minorInterval(labeled: 0.5, pixelsPerSecond: 600)
        )
    }

    func testMinorIntervalNilWhenTooDense() {
        // 0.2 s × 5 pt/s = 1 pt is unreadable.
        XCTAssertNil(
            TimelineRulerMetrics.minorInterval(labeled: 1, pixelsPerSecond: 5)
        )
    }

    // MARK: Labels

    func testLabelUsesTenthsForSubSecondIntervals() {
        XCTAssertEqual(
            TimelineRulerMetrics.label(seconds: 0.3, interval: 0.1),
            "0:00.3"
        )
    }

    func testLabelUsesMinuteSecondsForSecondIntervals() {
        XCTAssertEqual(
            TimelineRulerMetrics.label(seconds: 65, interval: 1),
            "1:05"
        )
    }

    func testLabelReadsMinutesAndHours() {
        XCTAssertEqual(
            TimelineRulerMetrics.label(seconds: 300, interval: 60),
            "5:00"
        )
        XCTAssertEqual(
            TimelineRulerMetrics.label(seconds: 7200, interval: 3600),
            "2:00:00"
        )
    }

    // MARK: Minute marks

    func testMinuteMarkIsTrueOnWholeMinutesForFineIntervals() {
        XCTAssertTrue(
            TimelineRulerMetrics.isMinuteMark(seconds: 120, interval: 5)
        )
        XCTAssertFalse(
            TimelineRulerMetrics.isMinuteMark(seconds: 123, interval: 5)
        )
    }

    func testMinuteMarkIsFalseWhenIntervalIsMinuteOrCoarser() {
        // Every labeled tick already reads as minutes; no emphasis needed.
        XCTAssertFalse(
            TimelineRulerMetrics.isMinuteMark(seconds: 60, interval: 60)
        )
    }
}
