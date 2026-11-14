import Foundation

/// The content kind a track holds.
nonisolated enum TrackKind: String, Codable, Hashable, Sendable {
    case video
    case audio
}

/// One ordered row of the timeline.
///
/// Track order convention: index 0 in `Composition.tracks` is the
/// **topmost** track in the user interface. New video tracks insert at
/// index 0 (stacking above existing ones); new audio tracks append
/// (stacking below all video tracks, as in a standard editor layout).
/// When rendering arrives it composites from the last index upward so
/// the topmost track paints last.
nonisolated struct Track: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    var name: String
    var kind: TrackKind
    var isVisible: Bool
    var isLocked: Bool

    /// Ordered clips. Clips on a track never overlap; placement helpers
    /// and validation maintain this invariant.
    var clips: [Clip]

    init(
        id: UUID = UUID(),
        name: String,
        kind: TrackKind,
        isVisible: Bool = true,
        isLocked: Bool = false,
        clips: [Clip] = []
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.isVisible = isVisible
        self.isLocked = isLocked
        self.clips = clips
    }

    /// The clip whose timeline range contains `time`, if any.
    func clip(at time: MediaTime) -> Clip? {
        clips.first { clip in
            let range = clip.timelineRange
            return time >= range.start && time < range.end
        }
    }

    /// The timeline position just past the last clip, or zero when the
    /// track is empty.
    var endOfLastClip: MediaTime {
        clips.map { $0.timelineRange.end }.max() ?? .zero
    }
}
