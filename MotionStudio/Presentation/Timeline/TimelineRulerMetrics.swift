import Foundation

/// Ruler tick math for the timeline, separated from the view so the
/// interval and label choices stay unit-testable.
///
/// The ruler has two tick layers: **labeled** ticks carry a timecode
/// label, and unlabeled **minor** ticks subdivide them. The labeled
/// interval is the finest candidate whose labels stay a readable
/// distance apart at the current zoom, so zooming out on a long video
/// naturally steps up through seconds, minutes, and hours.
nonisolated enum TimelineRulerMetrics {
    /// Candidate labeled-tick intervals in seconds, fine to coarse.
    static let labeledCandidates: [Double] = [
        0.1, 0.25, 0.5, 1, 2, 5, 10, 15, 30, 60, 120, 300, 600, 900, 1800, 3600
    ]

    /// The finest labeled interval whose labels are at least
    /// `minimumSpacing` points apart at the given zoom.
    static func labeledInterval(
        pixelsPerSecond: Double,
        minimumSpacing: Double = 90
    ) -> Double {
        labeledCandidates.first { $0 * pixelsPerSecond >= minimumSpacing }
            ?? labeledCandidates.last!
    }

    /// The unlabeled sub-tick interval: one fifth of the labeled
    /// interval when that stays readable (at least `minimumSpacing`
    /// points apart) and the labeled interval is a second or coarser.
    /// Finer than a second the labeled ticks are already dense, so no
    /// minors are drawn.
    static func minorInterval(
        labeled: Double,
        pixelsPerSecond: Double,
        minimumSpacing: Double = 8
    ) -> Double? {
        guard labeled >= 1 else { return nil }
        let candidate = labeled / 5
        return candidate * pixelsPerSecond >= minimumSpacing ? candidate : nil
    }

    /// The label for one tick. Below one-second intervals the label
    /// carries a tenth (`0:00.3`), because whole-second labels would
    /// repeat identically; coarser intervals use `M:SS` (`H:MM:SS`
    /// beyond an hour).
    static func label(seconds: Double, interval: Double) -> String {
        interval < 1
            ? PlaybackTimeFormatting.format(seconds: seconds)
            : PlaybackTimeFormatting.shortFormat(seconds: seconds)
    }

    /// True when a labeled tick falls on a whole minute (or hour), so
    /// the ruler can emphasize the marks that structure long timelines.
    static func isMinuteMark(seconds: Double, interval: Double) -> Bool {
        interval < 60 && seconds.truncatingRemainder(dividingBy: 60) == 0
    }
}
