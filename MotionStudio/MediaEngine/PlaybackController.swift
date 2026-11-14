import AVFoundation
import Foundation
import os

/// Playback failure with no more specific error from AVFoundation.
enum PlaybackControllerError: Error, LocalizedError {
    case unknownFailure

    var errorDescription: String? { "Playback failed" }

    var failureReason: String? {
        "The media could not be played. The file may be missing, damaged, or in an unsupported codec."
    }
}

/// Owns `AVPlayer` and exposes narrow playback state for the UI.
///
/// Responsibilities (architecture §7.2): play/pause, seek, current time,
/// duration, playback state, error reporting. Kept separate from SwiftUI —
/// the preview surface consumes `player` directly and everything else goes
/// through the methods below.
@MainActor
@Observable
final class PlaybackController {
    /// Backing player for the preview surface. Views must not mutate it;
    /// use the transport methods.
    private(set) var player: AVPlayer

    private(set) var isPlaying = false
    private(set) var currentTime: CMTime = .zero
    private(set) var duration: CMTime = .zero
    private(set) var isReadyToPlay = false

    /// True while an item is loaded, even before it is ready to play.
    private(set) var hasItem = false

    /// True when the most recently loaded item failed; cleared on load.
    private(set) var hasPlaybackFailure = false

    /// Called on the main actor when playback fails. The composition root
    /// wires this to error reporting.
    var onError: (@MainActor (Error) -> Void)?

    /// Called on the main actor whenever the playback position changes
    /// (periodic observation and explicit seeks). The composition root
    /// maps this into composition time for the timeline playhead.
    var onTimeChanged: (@MainActor (CMTime) -> Void)?

    /// Applied when the next loaded item becomes ready to play.
    private var pendingStartTime: CMTime?

    private var timeObserverToken: Any?
    private var itemStatusObservation: NSKeyValueObservation?
    private var playerStatusObservation: NSKeyValueObservation?

    private static let timeObserverInterval = CMTime(value: 1, timescale: 30)

    init(player: AVPlayer = AVPlayer()) {
        self.player = player

        // Track whether the player is running. This also catches automatic
        // pauses, such as reaching the end of the item.
        playerStatusObservation = player.observe(
            \.timeControlStatus,
            options: [.initial]
        ) { [weak self] player, _ in
            Task { @MainActor in
                self?.isPlaying = player.timeControlStatus != .paused
            }
        }
    }

    isolated deinit {
        // Runs on the main actor; AVPlayer retains its time observer, so
        // remove it before release.
        removeTimeObserver()
    }

    // MARK: Loading

    func load(url: URL, startAt: CMTime? = nil) {
        unload()
        AppLog.media.info("Loading media for playback: \(url.lastPathComponent, privacy: .public)")

        let item = AVPlayerItem(url: url)
        hasItem = true
        hasPlaybackFailure = false
        isReadyToPlay = false
        duration = .zero
        currentTime = .zero
        pendingStartTime = startAt
        player.replaceCurrentItem(with: item)

        itemStatusObservation = item.observe(\.status, options: [.initial]) { [weak self] item, _ in
            Task { @MainActor in
                self?.handleItemStatus(item)
            }
        }
        addTimeObserver()
    }

    func unload() {
        removeTimeObserver()
        itemStatusObservation?.invalidate()
        itemStatusObservation = nil
        player.pause()
        player.replaceCurrentItem(with: nil)
        hasItem = false
        hasPlaybackFailure = false
        isReadyToPlay = false
        isPlaying = false
        duration = .zero
        currentTime = .zero
        pendingStartTime = nil
    }

    private func handleItemStatus(_ item: AVPlayerItem) {
        switch item.status {
        case .readyToPlay:
            isReadyToPlay = true
            duration = item.duration
            if let start = pendingStartTime {
                pendingStartTime = nil
                currentTime = start
                player.seek(to: start, toleranceBefore: .zero, toleranceAfter: .zero)
                onTimeChanged?(start)
            }
            AppLog.media.info("Playback ready: duration \(item.duration.seconds, format: .fixed(precision: 2))s")
        case .failed:
            isReadyToPlay = false
            hasPlaybackFailure = true
            let failure = item.error ?? PlaybackControllerError.unknownFailure
            AppLog.media.error("Playback item failed: \(String(describing: failure), privacy: .public)")
            onError?(failure)
        default:
            break
        }
    }

    // MARK: Transport

    func play() {
        guard isReadyToPlay else { return }
        // Restart cleanly when the item previously played to the end.
        if isAtEnd {
            player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
        }
        player.play()
    }

    func pause() {
        player.pause()
    }

    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    /// Precise seek used by transport actions and scrub release.
    func seek(to time: CMTime) {
        guard isReadyToPlay else { return }
        currentTime = time
        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
        onTimeChanged?(time)
    }

    /// Fast seek while the user drags the scrubber; precise seek happens on
    /// release. The optimistic `currentTime` keeps the thumb consistent.
    func scrub(to seconds: Double) {
        guard isReadyToPlay else { return }
        let time = CMTime(seconds: seconds, preferredTimescale: 600)
        currentTime = time
        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .positiveInfinity)
    }

    func goToStart() {
        seek(to: .zero)
    }

    func goToEnd() {
        guard isReadyToPlay else { return }
        seek(to: duration)
    }

    private var isAtEnd: Bool {
        guard duration.isNumeric, duration.seconds > 0 else { return false }
        return currentTime.seconds >= duration.seconds - 0.05
    }

    // MARK: Time observation

    private func addTimeObserver() {
        guard timeObserverToken == nil else { return }
        timeObserverToken = player.addPeriodicTimeObserver(
            forInterval: Self.timeObserverInterval,
            queue: .main
        ) { [weak self] time in
            MainActor.assumeIsolated {
                guard let self, self.hasItem else { return }
                self.currentTime = time
                self.onTimeChanged?(time)
            }
        }
    }

    private func removeTimeObserver() {
        if let token = timeObserverToken {
            player.removeTimeObserver(token)
            timeObserverToken = nil
        }
    }
}
