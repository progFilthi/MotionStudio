import XCTest
@testable import MotionStudio

/// Tests for composition-time ↔ source-time mapping.
final class TimelineMapperTests: XCTestCase {
    private func makeTrack(withClip clip: Clip) -> Track {
        Track(name: "Video 1", kind: .video, clips: [clip])
    }

    private func makeClip(
        startSeconds: Double,
        durationSeconds: Double,
        sourceIn: Double
    ) -> Clip {
        Clip(
            name: "Clip",
            source: .asset(MediaAssetSource(assetID: UUID())),
            timelineStart: MediaTime.fromSeconds(startSeconds),
            timelineDuration: MediaTime.fromSeconds(durationSeconds),
            sourceIn: MediaTime.fromSeconds(sourceIn),
            sourceOut: MediaTime.fromSeconds(sourceIn + durationSeconds)
        )
    }

    func testClipAtTimeWithinRange() {
        let clip = makeClip(startSeconds: 2, durationSeconds: 3, sourceIn: 1)
        let track = makeTrack(withClip: clip)

        XCTAssertEqual(TimelineMapper.clip(at: MediaTime.fromSeconds(2.5), in: track)?.id, clip.id)
        XCTAssertEqual(TimelineMapper.clip(at: MediaTime.fromSeconds(4.999), in: track)?.id, clip.id)
        XCTAssertNil(TimelineMapper.clip(at: MediaTime.fromSeconds(1.999), in: track))
        XCTAssertNil(TimelineMapper.clip(at: MediaTime.fromSeconds(5), in: track))
    }

    func testCompositionToSourceMapping() {
        // Clip placed at 2 s on the timeline, playing source from 1 s.
        let clip = makeClip(startSeconds: 2, durationSeconds: 3, sourceIn: 1)

        let source = TimelineMapper.sourceTime(
            forCompositionTime: MediaTime.fromSeconds(2.5),
            in: clip
        )
        XCTAssertEqual(source, MediaTime.fromSeconds(1.5))
    }

    func testSourceToCompositionMapping() {
        let clip = makeClip(startSeconds: 2, durationSeconds: 3, sourceIn: 1)

        let composition = TimelineMapper.compositionTime(
            forSourceTime: MediaTime.fromSeconds(2),
            in: clip
        )
        XCTAssertEqual(composition, MediaTime.fromSeconds(3))
    }

    func testMappingRoundTrips() {
        let clip = makeClip(startSeconds: 4, durationSeconds: 2.5, sourceIn: 0.75)

        let source = TimelineMapper.sourceTime(
            forCompositionTime: MediaTime.fromSeconds(5.2),
            in: clip
        )
        let back = TimelineMapper.compositionTime(forSourceTime: source, in: clip)
        XCTAssertEqual(back, MediaTime.fromSeconds(5.2))
    }

    func testSearchAcrossTracksFindsTopmostFirst() {
        var composition = Composition(
            name: "Main",
            width: 1920,
            height: 1080,
            frameRate: .fps30,
            duration: MediaTime.fromSeconds(10),
            background: .black,
            tracks: []
        )

        let upper = makeClip(startSeconds: 0, durationSeconds: 2, sourceIn: 0)
        let lower = makeClip(startSeconds: 0, durationSeconds: 2, sourceIn: 0)
        composition.tracks = [
            Track(name: "Video 1", kind: .video, clips: [upper]),
            Track(name: "Video 2", kind: .video, clips: [lower]),
        ]

        let found = TimelineMapper.clip(at: .zero, in: composition)
        XCTAssertEqual(found?.clip.id, upper.id, "Index 0 (topmost) is searched first.")
    }
}
