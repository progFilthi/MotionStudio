import AVFoundation
import SwiftUI

/// Transport controls, scrubber, and time readout for the loaded media.
///
/// Controls are enabled only while media is ready to play; they never
/// appear interactive when they would do nothing.
struct PlaybackControlsView: View {
    let playback: PlaybackController

    /// Non-nil while the user drags the scrubber, so periodic time updates
    /// do not fight the thumb.
    @State private var scrubValue: Double?

    var body: some View {
        HStack(spacing: 12) {
            transportButtons
            if playback.isReadyToPlay {
                timeLabel
                scrubber
            }
        }
    }

    private var transportButtons: some View {
        let isControlEnabled = playback.isReadyToPlay
        return HStack(spacing: 16) {
            Button {
                playback.goToStart()
            } label: {
                Image(systemName: "backward.end.fill")
            }
            .foregroundStyle(isControlEnabled ? WorkspaceTheme.textPrimary : WorkspaceTheme.textTertiary)
            .help("Go to start")
            .disabled(!isControlEnabled)
            .accessibilityLabel("Go to start")

            Button {
                playback.togglePlayPause()
            } label: {
                Image(systemName: playback.isPlaying ? "pause.fill" : "play.fill")
            }
            .foregroundStyle(isControlEnabled ? WorkspaceTheme.textPrimary : WorkspaceTheme.textTertiary)
            .help(playback.isPlaying ? "Pause (Space)" : "Play (Space)")
            .disabled(!isControlEnabled)
            .accessibilityLabel(playback.isPlaying ? "Pause" : "Play")

            Button {
                playback.goToEnd()
            } label: {
                Image(systemName: "forward.end.fill")
            }
            .foregroundStyle(isControlEnabled ? WorkspaceTheme.textPrimary : WorkspaceTheme.textTertiary)
            .help("Go to end")
            .disabled(!isControlEnabled)
            .accessibilityLabel("Go to end")
        }
        .buttonStyle(.plain)
    }

    private var timeLabel: some View {
        Text("\(PlaybackTimeFormatting.format(playback.currentTime)) / \(PlaybackTimeFormatting.format(playback.duration))")
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundStyle(WorkspaceTheme.textSecondary)
            .lineLimit(1)
            .frame(minWidth: 100, alignment: .leading)
            .help("Current time / duration")
    }

    private var scrubber: some View {
        Slider(
            value: Binding(
                get: { scrubValue ?? playback.currentTime.seconds },
                set: { newValue in
                    scrubValue = newValue
                    playback.scrub(to: newValue)
                }
            ),
            in: 0...max(playback.duration.seconds, 0.001)
        ) { isEditing in
            if !isEditing {
                let finalValue = scrubValue ?? playback.currentTime.seconds
                playback.seek(to: CMTime(seconds: finalValue, preferredTimescale: 600))
                scrubValue = nil
            }
        }
        .frame(width: 220)
        .help("Seek")
    }
}
