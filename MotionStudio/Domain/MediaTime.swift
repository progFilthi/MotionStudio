import Foundation

/// Rounding rule for rational-time conversions.
///
/// Policies are explicit (architecture §5.3): conversions between
/// timescales and frame snapping must never pick a rule implicitly.
nonisolated enum MediaTimeRounding: String, Codable, Sendable {
    /// Rounds toward zero (truncation).
    case towardZero
    /// Rounds away from zero.
    case awayFromZero
    /// Rounds to nearest, with halfway cases rounding away from zero.
    case nearestAwayFromZero
}

/// Raised when a rational time is constructed with invalid components.
nonisolated enum MediaTimeError: Error, LocalizedError {
    case nonPositiveTimescale(Int32)

    var errorDescription: String? {
        switch self {
        case .nonPositiveTimescale(let timescale):
            return "A media time timescale must be positive (got \(timescale))."
        }
    }
}

/// Rational time: a count of units over a timescale.
///
/// This is the authoritative persisted representation of timeline time
/// (architecture §5.3). Floating-point seconds are derived, display-only
/// values here; they are never authoritative. Equality and comparison are
/// mathematical: `MediaTime(value: 1, timescale: 2)` equals
/// `MediaTime(value: 2, timescale: 4)`, while serialization preserves the
/// exact stored components.
nonisolated struct MediaTime: Codable, Hashable, Sendable, Comparable {
    /// Number of units. May be negative (a time before an origin).
    var value: Int64

    /// Units per second. Always positive.
    var timescale: Int32

    static let zero = try! MediaTime(value: 0, timescale: 600)

    /// Creates a rational time.
    /// - Throws: `MediaTimeError.nonPositiveTimescale` when `timescale <= 0`.
    init(value: Int64, timescale: Int32) throws {
        guard timescale > 0 else {
            throw MediaTimeError.nonPositiveTimescale(timescale)
        }
        self.value = value
        self.timescale = timescale
    }

    /// Creates a non-throwing convenience for literal, known-valid
    /// construction sites. Prefer `init(value:timescale:)` in user paths.
    static func exact(_ value: Int64, over timescale: Int32) -> MediaTime {
        try! MediaTime(value: value, timescale: timescale)
    }

    /// Builds a rational time from floating-point seconds at a fixed
    /// timescale (display-grade precision, truncated toward zero).
    /// Negative and non-finite input maps to zero.
    static func fromSeconds(_ seconds: Double, timescale: Int32 = 600) -> MediaTime {
        guard seconds.isFinite, seconds > 0 else { return .zero }
        return .exact(Int64((seconds * Double(timescale)).rounded(.towardZero)), over: timescale)
    }

    /// Seconds, for display and float-based boundaries only.
    var seconds: Double {
        Double(value) / Double(timescale)
    }

    var isZero: Bool { value == 0 }
    var isNegative: Bool { value < 0 }

    // MARK: Codable (explicit, validated)

    private enum CodingKeys: String, CodingKey {
        case value
        case timescale
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let value = try container.decode(Int64.self, forKey: .value)
        let timescale = try container.decode(Int32.self, forKey: .timescale)
        guard timescale > 0 else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "MediaTime timescale must be positive (got \(timescale))."
                )
            )
        }
        self.value = value
        self.timescale = timescale
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(value, forKey: .value)
        try container.encode(timescale, forKey: .timescale)
    }

    // MARK: Equality and comparison

    /// Cross-multiplied comparison with a Double fallback for magnitudes
    /// beyond exact Int64 cross-multiplication.
    private func comparisonRelation(to other: MediaTime) -> Int {
        // value_a * timescale_b  vs  value_b * timescale_a
        let lhs = value.multipliedClamping(by: Int64(other.timescale))
        let rhs = other.value.multipliedClamping(by: Int64(timescale))
        if lhs != .max, rhs != .max {
            if lhs < rhs { return -1 }
            if lhs > rhs { return 1 }
            return 0
        }
        // Overflow fallback: double comparison is exact enough for
        // magnitudes in this range to order rationals correctly.
        let left = seconds
        let right = other.seconds
        if left < right { return -1 }
        if left > right { return 1 }
        return 0
    }

    static func == (lhs: MediaTime, rhs: MediaTime) -> Bool {
        lhs.comparisonRelation(to: rhs) == 0
    }

    static func < (lhs: MediaTime, rhs: MediaTime) -> Bool {
        lhs.comparisonRelation(to: rhs) < 0
    }

    /// Canonical hash form: reduced fraction with a positive timescale.
    func hash(into hasher: inout Hasher) {
        let canonical = normalized()
        hasher.combine(canonical.value)
        hasher.combine(canonical.timescale)
    }

    /// Reduces to lowest terms. The result is mathematically identical.
    func normalized() -> MediaTime {
        guard value != 0 else { return .exact(0, over: 600) }
        let divisor = gcd(abs(value), Int64(timescale))
        return .exact(value / divisor, over: Int32(Int64(timescale) / divisor))
    }

    private func gcd(_ a: Int64, _ b: Int64) -> Int64 {
        var a = a
        var b = b
        while b != 0 {
            (a, b) = (b, a % b)
        }
        return max(a, 1)
    }

    // MARK: Arithmetic

    /// Adds two rational times. The result uses the larger timescale;
    /// converting the operand to it applies `nearestAwayFromZero`.
    static func + (lhs: MediaTime, rhs: MediaTime) -> MediaTime {
        let timescale = max(lhs.timescale, rhs.timescale)
        let a = lhs.converted(toTimescale: timescale, rounding: .nearestAwayFromZero)
        let b = rhs.converted(toTimescale: timescale, rounding: .nearestAwayFromZero)
        return .exact(a.value + b.value, over: timescale)
    }

    /// Subtracts `rhs` from `lhs`, using the same policy as `+`.
    static func - (lhs: MediaTime, rhs: MediaTime) -> MediaTime {
        lhs + MediaTime.exact(-rhs.value, over: rhs.timescale)
    }

    /// Multiplies by a scalar, keeping the timescale.
    func scaled(by factor: Double) -> MediaTime {
        .exact(Int64((Double(value) * factor).rounded(.towardZero)), over: timescale)
    }

    /// Clamps into a closed range.
    func clamped(to range: ClosedRange<MediaTime>) -> MediaTime {
        min(max(self, range.lowerBound), range.upperBound)
    }

    // MARK: Conversion

    /// Converts to another timescale with an explicit rounding policy.
    ///
    /// In-range values convert exactly when the new timescale is a
    /// multiple of the current one; otherwise the rounding rule decides.
    func converted(
        toTimescale newTimescale: Int32,
        rounding: MediaTimeRounding
    ) -> MediaTime {
        guard newTimescale > 0 else {
            return .exact(0, over: timescale)
        }
        guard newTimescale != timescale else { return self }

        // value * newTimescale / timescale, computed to keep precision.
        let numerator = value.multipliedClamping(by: Int64(newTimescale))
        let denominator = Int64(timescale)

        if numerator == .max {
            // Overflow path: convert through Double (display-grade
            // precision for extreme magnitudes).
            let scaled = seconds * Double(newTimescale)
            return .exact(Int64(scaled), over: newTimescale)
        }

        let quotient = numerator.quotientAndRemainder(dividingBy: denominator)
        var result = quotient.quotient
        if quotient.remainder != 0 {
            switch rounding {
            case .towardZero:
                break
            case .awayFromZero:
                result += numerator > 0 ? 1 : -1
            case .nearestAwayFromZero:
                // remainder/denominator >= 0.5 rounds away from zero.
                let twiceRemainder = quotient.remainder.multipliedClamping(by: 2)
                if abs(twiceRemainder) >= abs(denominator) {
                    result += numerator > 0 ? 1 : -1
                }
            }
        }
        return .exact(result, over: newTimescale)
    }

    /// Snaps to the nearest frame boundary of a frame rate.
    func roundedToFrame(of frameRate: FrameRate, rounding: MediaTimeRounding) -> MediaTime {
        // frameIndex = round(value * numerator / (timescale * denominator))
        let numerator = value.multipliedClamping(by: Int64(frameRate.numerator))
        let denominator = Int64(timescale).multipliedClamping(by: Int64(frameRate.denominator))

        guard numerator != .max, denominator != .max, denominator > 0 else {
            let frames = seconds * frameRate.framesPerSecond
            let index = MediaTime.exact(Int64(frames), over: 1)
            return index.scaledToFrameDuration(of: frameRate)
        }

        let quotient = numerator.quotientAndRemainder(dividingBy: denominator)
        var frameIndex = quotient.quotient
        if quotient.remainder != 0 {
            switch rounding {
            case .towardZero:
                break
            case .awayFromZero:
                frameIndex += numerator > 0 ? 1 : -1
            case .nearestAwayFromZero:
                let twiceRemainder = quotient.remainder.multipliedClamping(by: 2)
                if abs(twiceRemainder) >= abs(denominator) {
                    frameIndex += numerator > 0 ? 1 : -1
                }
            }
        }
        return MediaTime.exact(frameIndex, over: 1).scaledToFrameDuration(of: frameRate)
    }

    private func scaledToFrameDuration(of frameRate: FrameRate) -> MediaTime {
        // `self` is a frame count at timescale 1; one frame of this rate
        // lasts `denominator` units over `numerator`.
        .exact(value * Int64(frameRate.denominator), over: frameRate.numerator)
    }
}

/// Overflow-clamping multiply used by comparison and conversion paths.
nonisolated extension Int64 {
    /// Multiplies, clamping to `Int64.max` on overflow. Callers detect the
    /// clamped case by comparing against `.max`.
    func multipliedClamping(by other: Int64) -> Int64 {
        let (product, overflow) = multipliedReportingOverflow(by: other)
        guard !overflow else { return .max }
        return product
    }
}
