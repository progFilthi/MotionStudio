import AVFoundation
import XCTest
@testable import MotionStudio

/// Tests for the playback controller against a real generated fixture.
@MainActor
final class PlaybackControllerTests: XCTestCase {
    private var controller: PlaybackController!
    private var reportedErrors: [Error] = []

    override func setUp() async throws {
        controller = PlaybackController()
        reportedErrors = []
        controller.onError = { [weak self] error in
            self?.reportedErrors.append(error)
        }
    }

    override func tearDown() async throws {
        controller.unload()
    }

    private func waitUntil(
        timeout: TimeInterval,
        _ label: String,
        condition: @escaping () -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            guard Date() < deadline else {
                XCTFail("Timed out waiting for \(label)")
                return
            }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
    }

    private func loadReadyFixture() async throws -> URL {
        let url = try await MediaFixtures.makeVideo(lengthSeconds: 0.5)
        controller.load(url: url)
        try await waitUntil(timeout: 5, "playback ready") { self.controller.isReadyToPlay }
        return url
    }

    func testLoadPreparesPlayback() async throws {
        let url = try await loadReadyFixture()
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertTrue(controller.hasItem)
        XCTAssertFalse(controller.hasPlaybackFailure)
        XCTAssertEqual(controller.duration.seconds, 0.5, accuracy: 0.15)
    }

    func testPlayPauseAndSeek() async throws {
        let url = try await loadReadyFixture()
        defer { try? FileManager.default.removeItem(at: url) }

        controller.togglePlayPause()
        try await waitUntil(timeout: 3, "playing") { self.controller.isPlaying }

        controller.togglePlayPause()
        try await waitUntil(timeout: 3, "paused") { !self.controller.isPlaying }

        controller.seek(to: CMTime(seconds: 0.2, preferredTimescale: 600))
        try await waitUntil(timeout: 3, "seek to settle") {
            abs(self.controller.currentTime.seconds - 0.2) < 0.08
        }
    }

    func testFailureIsReportedThroughOnError() async throws {
        let url = try MediaFixtures.makeTextFile(named: "motionstudio-broken-\(UUID().uuidString).mp4")
        defer { try? FileManager.default.removeItem(at: url) }

        controller.load(url: url)
        try await waitUntil(timeout: 5, "failure to be reported") { !self.reportedErrors.isEmpty }

        XCTAssertFalse(controller.isReadyToPlay)
        XCTAssertTrue(controller.hasPlaybackFailure)
    }
}
