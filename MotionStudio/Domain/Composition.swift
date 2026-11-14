import Foundation

/// Problems found while validating a composition or project.
nonisolated enum ProjectValidationError: Error, LocalizedError {
    case invalidDimensions(width: Int, height: Int)
    case nonPositiveDuration(MediaTime)
    case overlappingClips(trackName: String, clipName: String)
    case invalidTypography(String)
    case invalidAnimation(String)

    var errorDescription: String? {
        switch self {
        case .invalidDimensions(let width, let height):
            return "Composition dimensions must be positive (got \(width)×\(height))."
        case .nonPositiveDuration(let duration):
            return "Composition duration must be positive (got \(duration.seconds)s)."
        case .overlappingClips(let trackName, let clipName):
            return "Clip '\(clipName)' on track '\(trackName)' overlaps another clip."
        case .invalidTypography(let reason):
            return "Invalid typography: \(reason)."
        case .invalidAnimation(let reason):
            return "Invalid animation: \(reason)."
        }
    }
}

/// A composition: canvas dimensions, frame rate, duration, background,
/// and ordered tracks (architecture §5.4).
nonisolated struct Composition: Codable, Hashable, Sendable {
    /// Timescale used for composition time throughout the domain.
    static let timescale: Int32 = 600

    let id: UUID
    var name: String
    var width: Int
    var height: Int
    var frameRate: FrameRate
    var duration: MediaTime
    var background: RGBAColor
    var tracks: [Track]

    init(
        id: UUID = UUID(),
        name: String,
        width: Int,
        height: Int,
        frameRate: FrameRate,
        duration: MediaTime,
        background: RGBAColor,
        tracks: [Track]
    ) {
        self.id = id
        self.name = name
        self.width = width
        self.height = height
        self.frameRate = frameRate
        self.duration = duration
        self.background = background
        self.tracks = tracks
    }

    /// First track of a kind, creating a named one when absent.
    ///
    /// New video tracks insert at index 0 (topmost); new audio tracks
    /// append below everything (see `Track` order convention).
    mutating func track(
        forKind kind: TrackKind,
        named fallbackName: String
    ) -> Track {
        if let existing = tracks.first(where: { $0.kind == kind }) {
            return existing
        }
        let track = Track(name: fallbackName, kind: kind)
        switch kind {
        case .video:
            tracks.insert(track, at: 0)
        case .audio:
            tracks.append(track)
        }
        return track
    }

    /// Validates dimensions, duration, clip overlap invariants, and
    /// clip-level content (typography, animations).
    func validate() throws {
        guard width > 0, height > 0 else {
            throw ProjectValidationError.invalidDimensions(width: width, height: height)
        }
        guard duration > .zero else {
            throw ProjectValidationError.nonPositiveDuration(duration)
        }
        for track in tracks {
            for (index, clip) in track.clips.enumerated() where index > 0 {
                let previous = track.clips[index - 1]
                if clip.timelineStart < previous.timelineRange.end {
                    throw ProjectValidationError.overlappingClips(
                        trackName: track.name,
                        clipName: clip.name
                    )
                }
            }
            for clip in track.clips {
                try clip.validate()
            }
        }
    }
}
