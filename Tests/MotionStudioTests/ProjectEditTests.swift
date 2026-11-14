import XCTest
@testable import MotionStudio

/// Tests for project edit semantics: asset registration and timeline
/// clip placement.
final class ProjectEditTests: XCTestCase {
    private func makeVideoAsset(named name: String = "Clip", seconds: Double = 2) -> MediaAsset {
        MediaAsset(
            name: name,
            kind: .video,
            policy: .linked,
            storagePath: "/Movies/\(name).mp4",
            duration: MediaTime.fromSeconds(seconds),
            pixelWidth: 1920,
            pixelHeight: 1080,
            addedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }

    func testFirstClipPlacesOnVideoTrackAtZero() {
        var project = Project.empty(schemaVersion: PackageFormat.currentSchemaVersion)
        let asset = makeVideoAsset()

        let clip = project.addTimelineClip(for: asset)

        XCTAssertEqual(clip.name, asset.name)
        XCTAssertEqual(clip.timelineStart, .zero)
        XCTAssertEqual(clip.timelineDuration, asset.duration)
        XCTAssertEqual(clip.sourceIn, .zero)
        XCTAssertEqual(clip.sourceOut, asset.duration)
        XCTAssertEqual(clip.source, .asset(MediaAssetSource(assetID: asset.id)))
    }

    func testSecondClipPlacesAfterFirst() {
        var project = Project.empty(schemaVersion: PackageFormat.currentSchemaVersion)
        let originalDuration = project.composition.duration
        let first = project.addTimelineClip(for: makeVideoAsset(named: "A"))
        let second = project.addTimelineClip(for: makeVideoAsset(named: "B"))

        XCTAssertEqual(second.timelineStart, first.timelineRange.end)
        // Both clips fit inside the default composition duration, so it
        // does not change.
        XCTAssertEqual(project.composition.duration, originalDuration)
    }

    func testClipWithinDefaultDurationDoesNotExtendIt() {
        var project = Project.empty(schemaVersion: PackageFormat.currentSchemaVersion)
        let originalDuration = project.composition.duration
        _ = project.addTimelineClip(for: makeVideoAsset(seconds: 2))

        XCTAssertEqual(project.composition.duration, originalDuration)
    }

    func testClipPastDefaultDurationExtendsComposition() {
        var project = Project.empty(schemaVersion: PackageFormat.currentSchemaVersion)
        _ = project.addTimelineClip(for: makeVideoAsset(seconds: 30))

        XCTAssertEqual(project.composition.duration, MediaTime.fromSeconds(30))
    }

    func testAudioOnlyAssetCreatesAudioTrackBelowVideo() {
        var project = Project.empty(schemaVersion: PackageFormat.currentSchemaVersion)
        var asset = makeVideoAsset(named: "Voiceover")
        asset.kind = .audio

        _ = project.addTimelineClip(for: asset)

        XCTAssertEqual(project.composition.tracks.count, 2)
        XCTAssertEqual(project.composition.tracks.first?.kind, .video)
        XCTAssertEqual(project.composition.tracks.last?.kind, .audio)
        XCTAssertEqual(project.composition.tracks.last?.name, "Audio 1")
    }

    func testSecondVideoClipReusesExistingVideoTrack() {
        var project = Project.empty(schemaVersion: PackageFormat.currentSchemaVersion)
        _ = project.addTimelineClip(for: makeVideoAsset(named: "A"))
        _ = project.addTimelineClip(for: makeVideoAsset(named: "B"))

        XCTAssertEqual(project.composition.tracks.count, 1)
        XCTAssertEqual(project.composition.tracks[0].clips.count, 2)
    }

    func testClipsStayNonOverlapping() throws {
        var project = Project.empty(schemaVersion: PackageFormat.currentSchemaVersion)
        _ = project.addTimelineClip(for: makeVideoAsset(named: "A", seconds: 3))
        _ = project.addTimelineClip(for: makeVideoAsset(named: "B", seconds: 3))

        try project.composition.validate() // must not throw
    }

    func testValidateDetectsOverlap() {
        var project = Project.empty(schemaVersion: PackageFormat.currentSchemaVersion)
        _ = project.addTimelineClip(for: makeVideoAsset(named: "A", seconds: 3))

        // Force an overlap by shifting the second clip's start earlier.
        let asset = makeVideoAsset(named: "B", seconds: 3)
        project.addAsset(asset)
        let clip = Clip(
            name: asset.name,
            source: .asset(MediaAssetSource(assetID: asset.id)),
            timelineStart: .exact(500, over: 600),
            timelineDuration: asset.duration,
            sourceIn: .zero,
            sourceOut: asset.duration
        )
        project.composition.tracks[0].clips.append(clip)

        XCTAssertThrowsError(try project.composition.validate()) { error in
            guard case ProjectValidationError.overlappingClips = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testAssetLookupAndUniquenessHelpers() {
        var project = Project.empty(schemaVersion: PackageFormat.currentSchemaVersion)
        let asset = makeVideoAsset()
        project.addAsset(asset)

        XCTAssertEqual(project.asset(withID: asset.id)?.name, "Clip")
        XCTAssertNil(project.asset(withID: UUID()))
        XCTAssertTrue(project.containsAsset(atPath: "/Movies/Clip.mp4"))
        XCTAssertFalse(project.containsAsset(atPath: "/Movies/Other.mp4"))
    }

    func testLastTimelineClipForAsset() {
        var project = Project.empty(schemaVersion: PackageFormat.currentSchemaVersion)
        let assetA = makeVideoAsset(named: "A")
        let assetB = makeVideoAsset(named: "B")
        project.addAsset(assetA)
        project.addAsset(assetB)

        let secondA = project.addTimelineClip(for: assetA)
        _ = project.addTimelineClip(for: assetB)

        XCTAssertEqual(project.lastTimelineClip(forAssetID: assetA.id)?.id, secondA.id)
        XCTAssertNil(project.lastTimelineClip(forAssetID: UUID()))
    }

    func testClipWithIDLookup() {
        var project = Project.empty(schemaVersion: PackageFormat.currentSchemaVersion)
        let clip = project.addTimelineClip(for: makeVideoAsset())

        let found = project.clip(withID: clip.id)
        XCTAssertEqual(found?.clip.id, clip.id)
        XCTAssertEqual(found?.track.kind, .video)
        XCTAssertNil(project.clip(withID: UUID()))
    }
}

/// Tests for composition track creation and ordering conventions.
final class CompositionTrackTests: XCTestCase {
    func testTrackForKindReusesExisting() {
        var composition = Composition(
            name: "Main",
            width: 1920,
            height: 1080,
            frameRate: .fps30,
            duration: MediaTime.fromSeconds(10),
            background: .black,
            tracks: [Track(name: "Video 1", kind: .video)]
        )

        let reused = composition.track(forKind: .video, named: "Video 2")
        XCTAssertEqual(reused.name, "Video 1")
        XCTAssertEqual(composition.tracks.count, 1)
    }

    func testTrackForKindCreatesWhenAbsent() {
        var composition = Composition(
            name: "Main",
            width: 1920,
            height: 1080,
            frameRate: .fps30,
            duration: MediaTime.fromSeconds(10),
            background: .black,
            tracks: []
        )

        _ = composition.track(forKind: .video, named: "Video 1")
        XCTAssertEqual(composition.tracks.count, 1)
        XCTAssertEqual(composition.tracks[0].name, "Video 1")
    }

    func testNewAudioTrackAppendsBelow() {
        var composition = Composition(
            name: "Main",
            width: 1920,
            height: 1080,
            frameRate: .fps30,
            duration: MediaTime.fromSeconds(10),
            background: .black,
            tracks: [Track(name: "Video 1", kind: .video)]
        )

        _ = composition.track(forKind: .audio, named: "Audio 1")
        XCTAssertEqual(composition.tracks.last?.kind, .audio)
        XCTAssertEqual(composition.tracks.first?.kind, .video)
    }
}
