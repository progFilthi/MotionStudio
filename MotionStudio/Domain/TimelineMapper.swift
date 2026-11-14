import Foundation

/// Pure composition-time ↔ source-time mapping for the single-clip
/// timeline playback workflow (architecture §7.3).
///
/// Milestone 2 previews one selected clip through AVPlayer: seeking the
/// timeline maps a composition position into the containing clip's
/// source time, and the periodic playback position maps back. Multi-clip
/// continuous playback arrives with the composition/playback adapter.
nonisolated enum TimelineMapper {
    /// The clip on `track` whose range contains `time`.
    static func clip(at time: MediaTime, in track: Track) -> Clip? {
        track.clip(at: time)
    }

    /// Source time corresponding to a composition position within a clip.
    static func sourceTime(forCompositionTime time: MediaTime, in clip: Clip) -> MediaTime {
        clip.sourceTime(forCompositionTime: time)
    }

    /// Composition position corresponding to a source time of a clip.
    static func compositionTime(forSourceTime time: MediaTime, in clip: Clip) -> MediaTime {
        clip.compositionTime(forSourceTime: time)
    }

    /// The first track that contains a clip at `time`, searched in
    /// display order (topmost first).
    static func clip(at time: MediaTime, in composition: Composition) -> (track: Track, clip: Clip)? {
        for track in composition.tracks {
            if let clip = clip(at: time, in: track) {
                return (track, clip)
            }
        }
        return nil
    }
}
