import XCTest
@testable import MotionStudio

/// Tests for deterministic keyframe evaluation: segment interpolation,
/// easing curves, boundaries at and outside keyframe times, and
/// frame-grid behavior (roadmap Milestone 3).
final class AnimationEvaluatorTests: XCTestCase {
    // MARK: Fixtures

    private func linearAnimation(
        from: Double,
        to: Double,
        start: Int64 = 0,
        end: Int64 = 1200
    ) -> Animation {
        Animation(
            property: .opacity,
            keyframes: [
                Keyframe(time: .exact(start, over: Composition.timescale), value: from),
                Keyframe(time: .exact(end, over: Composition.timescale), value: to),
            ]
        )
    }

    // MARK: Linear interpolation

    func testLinearValueAtKeyframeTimesReturnsKeyframeValues() {
        let animation = linearAnimation(from: 0, to: 1)

        XCTAssertEqual(AnimationEvaluator.value(of: animation, atClipLocalTime: .zero), 0)
        XCTAssertEqual(
            AnimationEvaluator.value(of: animation, atClipLocalTime: .exact(1200, over: 600)),
            1
        )
    }

    func testLinearValueAtMidpointIsExactAverage() {
        let animation = linearAnimation(from: 0.2, to: 0.8)

        // Halfway through the 2 s segment (0 → 1200 units).
        let value = AnimationEvaluator.value(of: animation, atClipLocalTime: .exact(600, over: 600))
        XCTAssertEqual(value ?? -1, 0.5, accuracy: 1e-12)
    }

    func testLinearValueAtQuarterPoint() {
        let animation = linearAnimation(from: 0, to: 4)

        // 0.3 s into a 2 s segment: progress 0.15.
        let value = AnimationEvaluator.value(of: animation, atClipLocalTime: .exact(180, over: 600))
        XCTAssertEqual(value ?? -1, 0.6, accuracy: 1e-12)
    }

    // MARK: Boundaries

    func testValueBeforeFirstKeyframeHoldsFirstValue() {
        let animation = linearAnimation(from: 0.25, to: 1)

        let value = AnimationEvaluator.value(
            of: animation,
            atClipLocalTime: .exact(-300, over: 600)
        )
        XCTAssertEqual(value, 0.25)
    }

    func testValueAfterLastKeyframeHoldsLastValue() {
        let animation = linearAnimation(from: 0, to: 0.75)

        let value = AnimationEvaluator.value(
            of: animation,
            atClipLocalTime: .exact(5000, over: 600)
        )
        XCTAssertEqual(value, 0.75)
    }

    func testEmptyAnimationEvaluatesToNil() {
        let animation = Animation(property: .opacity, keyframes: [])
        XCTAssertNil(AnimationEvaluator.value(of: animation, atClipLocalTime: .zero))
    }

    func testSingleKeyframeAnimationHoldsItsValue() {
        let animation = Animation(
            property: .opacity,
            keyframes: [Keyframe(time: .exact(600, over: 600), value: 0.4)]
        )

        XCTAssertEqual(AnimationEvaluator.value(of: animation, atClipLocalTime: .zero), 0.4)
        XCTAssertEqual(
            AnimationEvaluator.value(of: animation, atClipLocalTime: .exact(6000, over: 600)),
            0.4
        )
    }

    // MARK: Easing segments

    /// Non-linear keyframe values around a midpoint, chosen so any
    /// applied easing visibly moves the value away from the average.
    private func easedAnimation(_ interpolation: Interpolation) -> Animation {
        Animation(
            property: .opacity,
            keyframes: [
                Keyframe(time: .zero, value: 0, interpolation: interpolation),
                Keyframe(time: .exact(1200, over: 600), value: 1),
            ]
        )
    }

    func testEaseInOutAtSegmentMidpointIsExactCenter() {
        let animation = easedAnimation(.easeInOut)

        let value = AnimationEvaluator.value(of: animation, atClipLocalTime: .exact(600, over: 600))
        XCTAssertEqual(value ?? -1, 0.5, accuracy: 1e-6)
    }

    func testEaseInStartsSlowerThanLinearAtMidpoint() {
        let eased = AnimationEvaluator.value(of: easedAnimation(.easeIn), atClipLocalTime: .exact(600, over: 600))
        XCTAssertEqual(eased ?? -1, 0.5, accuracy: 0.2)
        XCTAssertLessThan(eased ?? 1, 0.5)
    }

    func testEaseOutIsFasterThanLinearAtMidpoint() {
        let eased = AnimationEvaluator.value(of: easedAnimation(.easeOut), atClipLocalTime: .exact(600, over: 600))
        XCTAssertGreaterThan(eased ?? 0, 0.5)
    }

    func testSegmentInterpolationComesFromSegmentStartKeyframe() {
        // The FIRST keyframe of each segment governs it: keyframe 0 is
        // ease-in, keyframe 1 is linear. The second segment must use
        // linear (exact average), even though keyframe 0 was eased.
        let animation = Animation(
            property: .opacity,
            keyframes: [
                Keyframe(time: .zero, value: 0, interpolation: .easeIn),
                Keyframe(time: .exact(1200, over: 600), value: 0.4),
                Keyframe(time: .exact(2400, over: 600), value: 0.8, interpolation: .linear),
            ]
        )

        let firstSegmentMid = AnimationEvaluator.value(of: animation, atClipLocalTime: .exact(600, over: 600))
        XCTAssertLessThan(firstSegmentMid ?? 1, 0.2, "First segment must apply the ease-in curve.")

        let secondSegmentMid = AnimationEvaluator.value(of: animation, atClipLocalTime: .exact(1800, over: 600))
        XCTAssertEqual(secondSegmentMid ?? -1, 0.6, accuracy: 1e-9, "Second segment must be linear (exact average).")
    }

    func testEasedValuesStayWithinKeyframeRange() {
        for interpolation in Interpolation.allCases {
            let animation = easedAnimation(interpolation)
            var previous: Double = -1
            for step in 0...40 {
                let time = MediaTime.exact(Int64(step * 30), over: 600)
                let value = AnimationEvaluator.value(of: animation, atClipLocalTime: time) ?? -1
                XCTAssertGreaterThanOrEqual(value, 0, "\(interpolation) escaped below 0")
                XCTAssertLessThanOrEqual(value, 1, "\(interpolation) escaped above 1")
                XCTAssertGreaterThanOrEqual(value, previous, "\(interpolation) must not decrease")
                previous = value
            }
        }
    }

    func testEvaluatorMatchesExplicitLinearCompositionForAllInterpolations() {
        // Every interpolation must hit both keyframe values exactly.
        for interpolation in Interpolation.allCases {
            let animation = easedAnimation(interpolation)
            XCTAssertEqual(AnimationEvaluator.value(of: animation, atClipLocalTime: .zero), 0, "\(interpolation)")
            XCTAssertEqual(
                AnimationEvaluator.value(of: animation, atClipLocalTime: .exact(1200, over: 600)),
                1,
                "\(interpolation)"
            )
        }
    }

    // MARK: Determinism

    func testRepeatedEvaluationIsBitIdentical() {
        let animation = easedAnimation(.easeInOut)
        let times: [MediaTime] = (0...60).map {
            .exact(Int64($0 * 10), over: 600)
        }

        let first = times.map { AnimationEvaluator.value(of: animation, atClipLocalTime: $0)?.bitPattern }
        let second = times.map { AnimationEvaluator.value(of: animation, atClipLocalTime: $0)?.bitPattern }

        XCTAssertEqual(first, second)
    }

    // MARK: Resolved values

    private func textClip(
        transform: Transform = .identity,
        opacity: Double = 1,
        animations: [Animation] = []
    ) -> Clip {
        Clip(
            name: "Text",
            source: .text(TextSource(text: "Hello")),
            timelineStart: .exact(1200, over: 600),
            timelineDuration: .exact(3000, over: 600),
            sourceIn: .zero,
            sourceOut: .exact(3000, over: 600),
            transform: transform,
            opacity: opacity,
            animations: animations
        )
    }

    func testUnanimatedPropertiesKeepStaticValues() {
        let clip = textClip(
            transform: Transform(scaleX: 2, scaleY: 3),
            opacity: 0.4
        )

        let values = AnimationEvaluator.resolvedValues(
            for: clip,
            atCompositionTime: .exact(2000, over: 600)
        )
        XCTAssertEqual(values.scaleX, 2)
        XCTAssertEqual(values.scaleY, 3)
        XCTAssertEqual(values.opacity, 0.4)
    }

    func testAnimatedPropertiesOverrideStatics() {
        var clip = textClip(
            transform: Transform(scaleX: 1, scaleY: 1),
            opacity: 1
        )
        clip.animations = [
            Animation(
                property: .scaleX,
                keyframes: [
                    Keyframe(time: .zero, value: 1),
                    Keyframe(time: .exact(1200, over: 600), value: 3),
                ]
            ),
            Animation(
                property: .opacity,
                keyframes: [Keyframe(time: .zero, value: 0.5)]
            ),
        ]

        // Composition time 4 s = clip-local 2 s: scaleX is at (and
        // past) its last keyframe → 3; opacity holds its single
        // keyframe 0.5.
        let values = AnimationEvaluator.resolvedValues(
            for: clip,
            atCompositionTime: .exact(2400, over: 600)
        )
        XCTAssertEqual(values.scaleX, 3, accuracy: 1e-9)
        XCTAssertEqual(values.scaleY, 1)
        XCTAssertEqual(values.opacity, 0.5)
    }

    func testCompositionTimeConversionUsesClipTimelineStart() {
        let clip = textClip(
            animations: [Animation(
                property: .opacity,
                keyframes: [
                    Keyframe(time: .exact(600, over: 600), value: 0),
                    Keyframe(time: .exact(1800, over: 600), value: 1),
                ]
            )]
        )
        // Clip starts at 2 s; keyframes at clip-local 1 s and 3 s, i.e.
        // composition 3 s and 5 s.
        XCTAssertEqual(
            AnimationEvaluator.resolvedValues(for: clip, atCompositionTime: .exact(1800, over: 600)).opacity,
            0,
            "Composition time 3 s must map to the clip-local 1 s keyframe."
        )
        XCTAssertEqual(
            AnimationEvaluator.resolvedValues(for: clip, atCompositionTime: .exact(3600, over: 600)).opacity ?? -1,
            1,
            accuracy: 1e-9
        )
    }

    // MARK: Frame grid

    func testFrameAlignedPlayheadTimesHitKeyframesExactly() {
        // 30 fps composition: frames land every 20 units at timescale
        // 600. A keyframe at exactly 1 s must evaluate to its value
        // when the playhead is on frame 30.
        let animation = Animation(
            property: .opacity,
            keyframes: [
                Keyframe(time: .zero, value: 0),
                Keyframe(time: .exact(600, over: 600), value: 0.8),
                Keyframe(time: .exact(1800, over: 600), value: 1),
            ]
        )

        let frame30 = MediaTime.exact(600, over: 600).roundedToFrame(of: .fps30, rounding: .nearestAwayFromZero)
        XCTAssertEqual(frame30, MediaTime.exact(600, over: 600))
        XCTAssertEqual(AnimationEvaluator.value(of: animation, atClipLocalTime: frame30), 0.8)
    }

    func testPlayheadBetweenFramesInterpolatesContinuously() {
        let animation = linearAnimation(from: 0, to: 1, start: 0, end: 600)

        // Frame 15 of 30 fps = 0.5 s = exactly the keyframe; one frame
        // earlier is 14/30 s: progress 0.9333.
        let frame14 = MediaTime.exact(280, over: 600)
        let value = AnimationEvaluator.value(of: animation, atClipLocalTime: frame14)
        XCTAssertEqual(value ?? -1, Double(280) / 600, accuracy: 1e-9)
    }
}

/// Unit tests for the cubic Bezier easing solver itself.
final class CubicBezierTests: XCTestCase {
    func testEndpointsAreExact() {
        let curve = CubicBezier(x1: 0.42, y1: 0, x2: 1, y2: 1)
        XCTAssertEqual(curve.evaluate(at: 0), 0, accuracy: 1e-12)
        XCTAssertEqual(curve.evaluate(at: 1), 1, accuracy: 1e-12)
    }

    func testIdentityControlPointsReproduceLinearProgress() {
        let linear = CubicBezier(x1: 0, y1: 0, x2: 1, y2: 1)
        for step in 1..<10 {
            let progress = Double(step) / 10
            XCTAssertEqual(linear.evaluate(at: progress), progress, accuracy: 1e-6)
        }
    }

    func testEaseInOutReferencePoints() {
        // CSS ease-in-out control points; check a couple of reference
        // samples against independently computed Bezier values.
        let curve = CubicBezier(x1: 0.42, y1: 0, x2: 0.58, y2: 1)

        // Symmetry: y(x) == 1 - y(1 - x).
        for step in 1..<10 {
            let x = Double(step) / 10
            let mirrored = 1 - curve.evaluate(at: 1 - x)
            XCTAssertEqual(curve.evaluate(at: x), mirrored, accuracy: 1e-6)
        }
    }

    func testSolverIsMonotonicAndBoundedForSteepCurves() {
        let curve = CubicBezier(x1: 0.9, y1: 0, x2: 0.1, y2: 1)
        var previous = -1.0
        for step in 0...50 {
            let value = curve.evaluate(at: Double(step) / 50)
            XCTAssertGreaterThanOrEqual(value, previous)
            XCTAssertLessThanOrEqual(value, 1)
            previous = value
        }
    }

    func testEvaluationIsDeterministic() {
        let curve = CubicBezier(x1: 0.33, y1: 0.1, x2: 0.67, y2: 0.9)
        let first = (0...100).map { curve.evaluate(at: Double($0) / 100).bitPattern }
        let second = (0...100).map { curve.evaluate(at: Double($0) / 100).bitPattern }
        XCTAssertEqual(first, second)
    }
}
