import Foundation

/// The effective animated state of a clip at one moment.
///
/// Animated properties carry the evaluated value; properties without an
/// animation keep the clip's static value. Pure value type, no
/// SwiftUI or rendering dependency (architecture §13).
nonisolated struct ResolvedClipValues: Hashable, Sendable {
    var scaleX: Double
    var scaleY: Double
    var opacity: Double
}

/// Deterministic evaluation of keyframe animations at arbitrary
/// timestamps (architecture §5.9).
///
/// The evaluator is a pure function of (animation, time) → value with
/// no hidden state, no clock, and no UI dependency, so the same project
/// always evaluates to the same values — in previews, in tests, and
/// later in the render engine.
///
/// Evaluation semantics:
///
/// - Keyframe times are clip-local composition time: zero is the
///   moment the clip starts on the timeline.
/// - Before the first keyframe the first value holds; after the last
///   keyframe the last value holds. Outside the span the animation
///   never changes.
/// - Each segment (keyframe *i* → keyframe *i+1*) is governed by
///   keyframe *i*'s interpolation.
/// - A static clip (no animation, or an animation without keyframes)
///   keeps its static value.
nonisolated enum AnimationEvaluator {
    /// Effective scale and opacity of a clip at a composition time.
    ///
    /// - Parameters:
    ///   - clip: the clip whose animations and static values are used.
    ///   - compositionTime: timeline position, converted to clip-local
    ///     time internally.
    static func resolvedValues(
        for clip: Clip,
        atCompositionTime compositionTime: MediaTime
    ) -> ResolvedClipValues {
        resolvedValues(for: clip, atClipLocalTime: compositionTime - clip.timelineStart)
    }

    /// Effective scale and opacity of a clip at a clip-local
    /// composition time (zero = the clip's timeline start).
    static func resolvedValues(
        for clip: Clip,
        atClipLocalTime time: MediaTime
    ) -> ResolvedClipValues {
        var values = ResolvedClipValues(
            scaleX: clip.transform.scaleX,
            scaleY: clip.transform.scaleY,
            opacity: clip.opacity
        )
        if let scaleX = clip.animation(for: .scaleX), let value = value(of: scaleX, atClipLocalTime: time) {
            values.scaleX = value
        }
        if let scaleY = clip.animation(for: .scaleY), let value = value(of: scaleY, atClipLocalTime: time) {
            values.scaleY = value
        }
        if let opacity = clip.animation(for: .opacity), let evaluated = value(of: opacity, atClipLocalTime: time) {
            values.opacity = evaluated
        }
        return values
    }

    /// The value of one animation at a clip-local composition time, or
    /// `nil` when the animation has no keyframes.
    static func value(of animation: Animation, atClipLocalTime time: MediaTime) -> Double? {
        guard let first = animation.keyframes.first, let last = animation.keyframes.last else {
            return nil
        }
        if time <= first.time {
            return first.value
        }
        if time >= last.time {
            return last.value
        }

        // Segment index: the last keyframe at or before `time`. The
        // boundary checks above guarantee `time > first.time` here, so
        // `index` is valid and `index + 1` exists.
        var index = 0
        for (candidate, keyframe) in animation.keyframes.enumerated() {
            if keyframe.time <= time {
                index = candidate
            } else {
                break
            }
        }

        let from = animation.keyframes[index]
        let to = animation.keyframes[index + 1]

        let segment = to.time - from.time
        let offset = time - from.time
        let progress = offset.seconds / segment.seconds

        let eased: Double
        switch from.interpolation {
        case .linear:
            eased = progress
        case .easeIn, .easeOut, .easeInOut:
            let points = from.interpolation.controlPoints
            eased = CubicBezier(
                x1: points.p1.x,
                y1: points.p1.y,
                x2: points.p2.x,
                y2: points.p2.y
            ).evaluate(at: progress)
        }

        return from.value + (to.value - from.value) * eased
    }
}

/// A cubic Bezier easing curve with the endpoints pinned to (0,0) and
/// (1,1), so only the two interior control points vary — the same shape
/// the CSS `cubic-bezier()` easing uses.
///
/// `evaluate(at:)` maps a linear progress value through the curve by
/// solving the x-polynomial for the curve parameter, then reading the
/// y-polynomial. The solver is deterministic: fixed iteration counts,
/// no randomness, no clock.
nonisolated struct CubicBezier: Hashable, Sendable {
    var x1: Double
    var y1: Double
    var x2: Double
    var y2: Double

    /// Interior control points whose x coordinates stay in 0…1 make the
    /// x-polynomial monotonically nondecreasing on 0…1, so the solve is
    /// unambiguous.
    func evaluate(at progress: Double) -> Double {
        guard progress > 0 else { return 0 }
        guard progress < 1 else { return 1 }
        let parameter = solveParameter(forX: progress)
        return cubic(at: parameter, p1: y1, p2: y2)
    }

    // MARK: Solver

    /// Solves `x(u) = target` for the curve parameter.
    ///
    /// Newton's method with a clamped iterate (8 fixed iterations), and
    /// a fixed-count bisection fallback when the derivative vanishes or
    /// the iterate leaves 0…1. Both phases are deterministic.
    private func solveParameter(forX target: Double) -> Double {
        // Newton-Raphson phase.
        var parameter = target
        var converged = false
        for _ in 0..<8 {
            let value = cubic(at: parameter, p1: x1, p2: x2) - target
            if abs(value) < 1e-7 {
                converged = true
                break
            }
            let derivative = cubicDerivative(at: parameter, p1: x1, p2: x2)
            guard abs(derivative) > 1e-6 else { break }
            parameter -= value / derivative
            if parameter < 0 { parameter = 0 }
            if parameter > 1 { parameter = 1 }
        }
        if converged {
            return parameter
        }

        // Bisection phase: 32 fixed halvings of 0…1 (interval ends
        // below 1e-9), always terminating in the same value.
        var low = 0.0
        var high = 1.0
        parameter = target
        for _ in 0..<32 {
            let value = cubic(at: parameter, p1: x1, p2: x2) - target
            if abs(value) < 1e-9 {
                return parameter
            }
            if value < 0 {
                low = parameter
            } else {
                high = parameter
            }
            parameter = (low + high) / 2
        }
        return parameter
    }

    /// Cubic Bezier polynomial for one axis with endpoints (0,0) and
    /// (1,1): `3(1−u)²u·p1 + 3(1−u)u²·p2 + u³`.
    private func cubic(at u: Double, p1: Double, p2: Double) -> Double {
        let oneMinus = 1 - u
        return 3 * oneMinus * oneMinus * u * p1
            + 3 * oneMinus * u * u * p2
            + u * u * u
    }

    /// Derivative of `cubic(at:p1:p2:)` with respect to `u`:
    /// `3(1−u)²·p1 + 6(1−u)u·(p2 − p1) + 3u²·(1 − p2)`.
    private func cubicDerivative(at u: Double, p1: Double, p2: Double) -> Double {
        let oneMinus = 1 - u
        return 3 * oneMinus * oneMinus * p1
            + 6 * oneMinus * u * (p2 - p1)
            + 3 * u * u * (1 - p2)
    }
}
