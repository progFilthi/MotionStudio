import Foundation

/// Raised when a frame rate is constructed with invalid components.
nonisolated enum FrameRateError: Error, LocalizedError {
    case nonPositiveComponent(numerator: Int32, denominator: Int32)

    var errorDescription: String? {
        switch self {
        case .nonPositiveComponent(let numerator, let denominator):
            return "A frame rate needs a positive numerator and denominator (got \(numerator)/\(denominator))."
        }
    }
}

/// Rational frame rate, preserving fractional rates such as 30000/1001
/// (architecture §5.3). Never reduced: 30000/1001 stays 30000/1001 so the
/// composition frame grid matches the source media exactly.
nonisolated struct FrameRate: Codable, Hashable, Sendable {
    var numerator: Int32
    var denominator: Int32

    static let fps24 = FrameRate.exact(24, over: 1)
    static let fps25 = FrameRate.exact(25, over: 1)
    static let fps30 = FrameRate.exact(30, over: 1)
    static let ntsc29_97 = FrameRate.exact(30000, over: 1001)
    static let ntsc59_94 = FrameRate.exact(60000, over: 1001)

    /// Creates a frame rate.
    /// - Throws: `FrameRateError.nonPositiveComponent` when either
    ///   component is not positive.
    init(numerator: Int32, denominator: Int32) throws {
        guard numerator > 0, denominator > 0 else {
            throw FrameRateError.nonPositiveComponent(
                numerator: numerator,
                denominator: denominator
            )
        }
        self.numerator = numerator
        self.denominator = denominator
    }

    /// Non-throwing convenience for known-valid construction sites.
    static func exact(_ numerator: Int32, over denominator: Int32) -> FrameRate {
        try! FrameRate(numerator: numerator, denominator: denominator)
    }

    /// Duration of exactly one frame.
    var frameDuration: MediaTime {
        .exact(Int64(denominator), over: numerator)
    }

    /// Exactly half of one frame's duration.
    ///
    /// Computed as a fresh rational (denominator over twice the
    /// numerator) because scaling the frame duration by 0.5 truncates
    /// to zero for odd numerators.
    var halfFrameDuration: MediaTime {
        .exact(Int64(denominator), over: numerator * 2)
    }

    /// Frames per second as a Double, for display and comparisons only.
    var framesPerSecond: Double {
        Double(numerator) / Double(denominator)
    }

    // MARK: Codable (explicit, validated)

    private enum CodingKeys: String, CodingKey {
        case numerator
        case denominator
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let numerator = try container.decode(Int32.self, forKey: .numerator)
        let denominator = try container.decode(Int32.self, forKey: .denominator)
        guard numerator > 0, denominator > 0 else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "FrameRate components must be positive (got \(numerator)/\(denominator))."
                )
            )
        }
        self.numerator = numerator
        self.denominator = denominator
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(numerator, forKey: .numerator)
        try container.encode(denominator, forKey: .denominator)
    }
}
