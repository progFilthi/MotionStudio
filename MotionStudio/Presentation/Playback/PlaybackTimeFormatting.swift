import AVFoundation
import Foundation

/// Formatting for playback time readouts.
nonisolated enum PlaybackTimeFormatting {
    /// Formats seconds as `M:SS.d`, or `H:MM:SS.d` for an hour or more.
    /// Invalid and negative times render as `0:00.0`.
    static func format(seconds: Double) -> String {
        let clamped = seconds.isFinite ? max(0, seconds) : 0
        let total = Int(clamped.rounded(.down))
        let tenths = Int((clamped * 10).rounded(.down)) % 10
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secondsPart = total % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d.%d", hours, minutes, secondsPart, tenths)
        }
        return String(format: "%d:%02d.%d", minutes, secondsPart, tenths)
    }

    /// Formats a `CMTime` for display; invalid times render as `0:00.0`.
    static func format(_ time: CMTime) -> String {
        format(seconds: time.seconds)
    }

    /// Formats seconds as `M:SS` (or `H:MM:SS`) for ruler labels, where
    /// whole-second resolution is enough.
    static func shortFormat(seconds: Double) -> String {
        let clamped = seconds.isFinite ? max(0, seconds) : 0
        let total = Int(clamped.rounded(.down))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secondsPart = total % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secondsPart)
        }
        return String(format: "%d:%02d", minutes, secondsPart)
    }
}
