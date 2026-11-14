import Foundation

/// The typed source a clip draws its content from (architecture §5.6).
///
/// The serialized form is explicit and stable: a `kind` discriminator, a
/// `version` for the case payload, and the payload fields themselves.
/// Synthesized Codable output is never the project file contract.
///
/// Milestone 2 has one case; text and shape content arrive with later
/// milestones. Unknown kinds and unknown payload versions are rejected at
/// decode time so corrupt or foreign files fail loudly instead of
/// silently dropping data.
nonisolated enum ClipSource: Codable, Hashable, Sendable {
    /// References a registered `MediaAsset` (video or audio).
    case asset(MediaAssetSource)

    private enum CodingKeys: String, CodingKey {
        case kind
        case version
        case assetID
    }

    private static let assetKind = "asset"
    private static let assetVersion = 1

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

/// One clip on a track: a piece of a source placed in the timeline.
///
/// Source time and timeline time are distinct (architecture §5.5): the
/// clip's `sourceIn` may be nonzero, and its timeline placement may
/// differ entirely from its source position.
///
/// Animations and effects are deliberately absent until Milestone 3 adds
/// them under a new schema version.
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

    init(
        id: UUID = UUID(),
        name: String,
        source: ClipSource,
        timelineStart: MediaTime,
        timelineDuration: MediaTime,
        sourceIn: MediaTime,
        sourceOut: MediaTime,
        transform: Transform = .identity,
        opacity: Double = 1
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
}
