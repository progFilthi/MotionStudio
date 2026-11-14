import Foundation

/// Easing curve applied between consecutive keyframes (architecture §5.9).
///
/// The keyframe's interpolation governs the segment that *starts* at
/// that keyframe and ends at the next one. Linear is the default for
/// newly created keyframes.
nonisolated enum Interpolation: String, Codable, CaseIterable, Hashable, Sendable {
    case linear
    case easeIn
    case easeOut
    case easeInOut

    var displayName: String {
        switch self {
        case .linear: return "Linear"
        case .easeIn: return "Ease In"
        case .easeOut: return "Ease Out"
        case .easeInOut: return "Ease In-Out"
        }
    }

    /// Control points of the cubic Bezier mapping progress (0…1) to
    /// output progress (0…1). Endpoint control points are pinned to
    /// (0,0) and (1,1), so only the two interior points vary.
    var controlPoints: (p1: (x: Double, y: Double), p2: (x: Double, y: Double)) {
        switch self {
        case .linear: return ((0, 0), (1, 1))
        case .easeIn: return ((0.42, 0), (1, 1))
        case .easeOut: return ((0, 0), (0.58, 1))
        case .easeInOut: return ((0.42, 0), (0.58, 1))
        }
    }
}

/// A single keyframe: a value at a clip-local composition time.
///
/// Time is in composition time (same timescale as the composition),
/// relative to the clip's `timelineStart`: a keyframe at time zero
/// fires when the clip begins on the timeline. Values are dimensionless
/// domain values (scale multipliers, opacity fractions) so the model
/// stays independent of any rendering boundary.
nonisolated struct Keyframe: Codable, Hashable, Sendable {
    /// Clip-local composition time of the keyframe.
    var time: MediaTime
    var value: Double
    var interpolation: Interpolation

    init(time: MediaTime, value: Double, interpolation: Interpolation = .linear) {
        self.time = time
        self.value = value
        self.interpolation = interpolation
    }

    private enum CodingKeys: String, CodingKey {
        case time
        case value
        case interpolation
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        time = try container.decode(MediaTime.self, forKey: .time)
        value = try container.decode(Double.self, forKey: .value)
        interpolation = try container.decodeIfPresent(Interpolation.self, forKey: .interpolation) ?? .linear
    }
}

/// A keyframed animation of one `AnimatableProperty` on one clip.
///
/// Keyframes are kept sorted by time; duplicate times are rejected by
/// validation so the mapping from time to value stays a function. The
/// model holds keyframes only — evaluation lives in the MotionEngine
/// evaluator, which stays independent of SwiftUI (architecture §13).
nonisolated struct Animation: Codable, Hashable, Sendable {
    var property: AnimatableProperty
    var keyframes: [Keyframe]

    init(property: AnimatableProperty, keyframes: [Keyframe] = []) {
        self.property = property
        self.keyframes = keyframes.sorted { $0.time < $1.time }
    }

    private enum CodingKeys: String, CodingKey {
        case property
        case keyframes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        property = try container.decode(AnimatableProperty.self, forKey: .property)
        keyframes = try container.decode([Keyframe].self, forKey: .keyframes)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(property, forKey: .property)
        try container.encode(keyframes, forKey: .keyframes)
    }

    /// The property's value when the animation has no keyframes.
    var isStatic: Bool { keyframes.isEmpty }

    /// The keyframe whose time falls within `tolerance` of `time`, if
    /// any. Used for hit-testing the playhead against keyframes with a
    /// half-frame tolerance.
    func keyframe(near time: MediaTime, tolerance: MediaTime) -> Keyframe? {
        keyframes.first { keyframe in
            keyframe.time + tolerance >= time && keyframe.time - tolerance <= time
        }
    }

    /// First and last keyframe times, or `nil` when static.
    var timeSpan: (start: MediaTime, end: MediaTime)? {
        guard let first = keyframes.first, let last = keyframes.last else { return nil }
        return (first.time, last.time)
    }

    /// Inserts a keyframe, keeping the list sorted by time. Fails if a
    /// keyframe already exists at (or within rounding of) that time.
    mutating func insert(_ keyframe: Keyframe) throws {
        let index = keyframes.firstIndex { $0.time >= keyframe.time }
        if let index {
            if keyframes[index].time == keyframe.time {
                throw ProjectValidationError.invalidAnimation(
                    "\(property.displayName) already has a keyframe at this time."
                )
            }
            keyframes.insert(keyframe, at: index)
        } else {
            keyframes.append(keyframe)
        }
    }

    /// Removes the keyframe at a clip-local composition time, if any.
    mutating func removeKeyframe(at time: MediaTime) {
        keyframes.removeAll { $0.time == time }
    }

    /// Replaces the value (and interpolation) of the keyframe at a
    /// clip-local composition time. Fails when no keyframe is there.
    mutating func updateKeyframe(at time: MediaTime, to value: Double, interpolation: Interpolation? = nil) throws {
        guard let index = keyframes.firstIndex(where: { $0.time == time }) else {
            throw ProjectValidationError.invalidAnimation(
                "\(property.displayName) has no keyframe at this time."
            )
        }
        keyframes[index].value = value
        if let interpolation {
            keyframes[index].interpolation = interpolation
        }
    }

    /// Validates keyframe count, ordering, times, values, and ranges
    /// appropriate to the animated property.
    func validate() throws {
        for (index, keyframe) in keyframes.enumerated() {
            guard keyframe.time >= .zero else {
                throw ProjectValidationError.invalidAnimation(
                    "\(property.displayName) keyframe time must not be negative."
                )
            }
            guard keyframe.value.isFinite else {
                throw ProjectValidationError.invalidAnimation(
                    "\(property.displayName) keyframe value must be finite."
                )
            }
            switch property {
            case .scaleX, .scaleY:
                guard keyframe.value >= 0 else {
                    throw ProjectValidationError.invalidAnimation(
                        "\(property.displayName) keyframe value must not be negative."
                    )
                }
            case .opacity:
                guard keyframe.value >= 0, keyframe.value <= 1 else {
                    throw ProjectValidationError.invalidAnimation(
                        "\(property.displayName) keyframe value must be between 0 and 1."
                    )
                }
            }
            if index > 0 {
                let previous = keyframes[index - 1]
                guard keyframe.time > previous.time else {
                    throw ProjectValidationError.invalidAnimation(
                        "\(property.displayName) keyframes must have strictly increasing times."
                    )
                }
            }
        }
    }
}
