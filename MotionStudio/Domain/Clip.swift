import Foundation

/// The typed source a clip draws its content from (architecture §5.6).
///
/// The serialized form is explicit and stable: a `kind` discriminator, a
/// `version` for the case payload, and the payload fields themselves.
/// Synthesized Codable output is never the project file contract.
///
/// - Milestone 2 has the asset case; text arrives with Milestone 3 and
///   further kinds with later milestones. Unknown kinds and unknown
///   payload versions are rejected at decode time so corrupt or foreign
///   files fail loudly instead of silently dropping data.
nonisolated enum ClipSource: Codable, Hashable, Sendable {
    /// References a registered `MediaAsset` (video or audio).
    case asset(MediaAssetSource)

    /// Typed text content with its own typography (architecture §5.8).
    case text(TextSource)

    private enum CodingKeys: String, CodingKey {
        case kind
        case version
        case assetID
        case text
        case typography
    }

    private static let assetKind = "asset"
    private static let assetVersion = 1
    private static let textKind = "text"
    private static let textVersion = 1

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(String.self, forKey: .kind)

        switch kind {
        case Self.assetKind:
            let version = try container.decode(Int.self, forKey: .version)
            guard version == Self.assetVersion else {
                throw DecodingError.dataCorruptedError(
                    forKey: .version,
                    in: container,
                    debugDescription: "Clip source payload version \(version) is not supported (expected \(Self.assetVersion))."
                )
            }
            self = .asset(MediaAssetSource(
                assetID: try container.decode(UUID.self, forKey: .assetID)
            ))
        case Self.textKind:
            let version = try container.decode(Int.self, forKey: .version)
            guard version == Self.textVersion else {
                throw DecodingError.dataCorruptedError(
                    forKey: .version,
                    in: container,
                    debugDescription: "Clip source payload version \(version) is not supported (expected \(Self.textVersion))."
                )
            }
            self = .text(TextSource(
                text: try container.decode(String.self, forKey: .text),
                typography: try container.decodeIfPresent(Typography.self, forKey: .typography) ?? .default
            ))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .kind,
                in: container,
                debugDescription: "Unknown clip source kind '\(kind)'."
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .asset(let source):
            try container.encode(Self.assetKind, forKey: .kind)
            try container.encode(Self.assetVersion, forKey: .version)
            try container.encode(source.assetID, forKey: .assetID)
        case .text(let text):
            try container.encode(Self.textKind, forKey: .kind)
            try container.encode(Self.textVersion, forKey: .version)
            try container.encode(text.text, forKey: .text)
            try container.encode(text.typography, forKey: .typography)
        }
    }
}

/// Payload of `ClipSource.asset`.
nonisolated struct MediaAssetSource: Codable, Hashable, Sendable {
    let assetID: UUID

    init(assetID: UUID) {
        self.assetID = assetID
    }
}

/// Payload of `ClipSource.text` (architecture §5.8).
nonisolated struct TextSource: Hashable, Sendable {
    /// The text content. Multi-line text uses `\n`.
    var text: String

    var typography: Typography

    init(text: String, typography: Typography = .default) {
        self.text = text
        self.typography = typography
    }
}

/// One clip on a track: a piece of a source placed in the timeline.
///
/// Source time and timeline time are distinct (architecture §5.5): the
/// clip's `sourceIn` may be nonzero, and its timeline placement may
/// differ entirely from its source position.
///
/// Each clip carries at most one animation per animatable property
/// (architecture §5.9); effects arrive with later milestones.
nonisolated struct Clip: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    var name: String
    var source: ClipSource

    /// Where the clip starts on the timeline.
    var timelineStart: MediaTime

    /// How long the clip plays on the timeline.
    var timelineDuration: MediaTime

    /// First source time the clip plays.
    var sourceIn: MediaTime

    /// Source time just past the last played moment.
    var sourceOut: MediaTime

    var transform: Transform
    var opacity: Double

    /// Keyframed property animations applied while the clip is on the
    /// timeline (Milestone 3: scale and opacity). At most one animation
    /// per animatable property; empty means no animation.
    var animations: [Animation]

    init(
        id: UUID = UUID(),
        name: String,
        source: ClipSource,
        timelineStart: MediaTime,
        timelineDuration: MediaTime,
        sourceIn: MediaTime,
        sourceOut: MediaTime,
        transform: Transform = .identity,
        opacity: Double = 1,
        animations: [Animation] = []
    ) {
        self.id = id
        self.name = name
        self.source = source
        self.timelineStart = timelineStart
        self.timelineDuration = timelineDuration
        self.sourceIn = sourceIn
        self.sourceOut = sourceOut
        self.transform = transform
        self.opacity = opacity
        self.animations = animations
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case source
        case timelineStart
        case timelineDuration
        case sourceIn
        case sourceOut
        case transform
        case opacity
        case animations
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        source = try container.decode(ClipSource.self, forKey: .source)
        timelineStart = try container.decode(MediaTime.self, forKey: .timelineStart)
        timelineDuration = try container.decode(MediaTime.self, forKey: .timelineDuration)
        sourceIn = try container.decode(MediaTime.self, forKey: .sourceIn)
        sourceOut = try container.decode(MediaTime.self, forKey: .sourceOut)
        transform = try container.decodeIfPresent(Transform.self, forKey: .transform) ?? .identity
        opacity = try container.decodeIfPresent(Double.self, forKey: .opacity) ?? 1
        animations = try container.decodeIfPresent([Animation].self, forKey: .animations) ?? []
    }

    /// Whether this clip is a typed text layer.
    var isText: Bool {
        if case .text = source { return true }
        return false
    }

    /// Whether the clip plays through AVFoundation in the current
    /// single-clip workflow. Text layers are previewed as overlays
    /// instead (Milestone 3), so seeking never treats them as media.
    var isPlayable: Bool {
        if case .asset = source { return true }
        return false
    }

    /// The animation for an animatable property, if any.
    func animation(for property: AnimatableProperty) -> Animation? {
        animations.first { $0.property == property }
    }

    /// Applies an edit to the animation of a property, if present.
    mutating func updateAnimation(
        for property: AnimatableProperty,
        perform: (inout Animation) -> Void
    ) {
        guard let index = animations.firstIndex(where: { $0.property == property }) else { return }
        perform(&animations[index])
    }

    /// Applies an edit to the text payload of a text clip. No-op on
    /// other source kinds.
    mutating func updateText(_ perform: (inout TextSource) -> Void) {
        guard case .text(let source) = source else { return }
        var updated = source
        perform(&updated)
        self.source = .text(updated)
    }

    /// The timeline range the clip occupies, inclusive start and end.
    var timelineRange: (start: MediaTime, end: MediaTime) {
        (timelineStart, timelineStart + timelineDuration)
    }

    /// Source time that corresponds to a timeline position inside the
    /// clip's range.
    func sourceTime(forCompositionTime time: MediaTime) -> MediaTime {
        sourceIn + (time - timelineStart)
    }

    /// Timeline position that corresponds to a source time.
    func compositionTime(forSourceTime time: MediaTime) -> MediaTime {
        timelineStart + (time - sourceIn)
    }

    /// Validates clip-level content: text typography and animations.
    func validate() throws {
        if case .text(let text) = source {
            try text.typography.validate()
        }
        for animation in animations {
            try animation.validate()
        }
    }
}
