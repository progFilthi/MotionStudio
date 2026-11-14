import XCTest
@testable import MotionStudio

/// Tests for the typed text layer model: track placement, clip
/// helpers, timeline invariants, and Milestone 3 validation
/// (roadmap Milestone 3).
final class TextLayerTests: XCTestCase {
    // MARK: Text track management

    func testTextTrackCreatesDedicatedTrackAtTop() {
        var project = Project.empty(schemaVersion: 2)

        let track = project.textTrack()

        XCTAssertEqual(track.name, "Text 1")
        XCTAssertEqual(track.kind, .video)
        XCTAssertEqual(project.composition.tracks.first?.id, track.id, "Text tracks insert topmost.")
    }

    func testTextTrackReusesAnExistingTextTrack() {
        var project = Project.empty(schemaVersion: 2)
        let first = project.textTrack()

        let second = project.textTrack()

        XCTAssertEqual(first.id, second.id)
        XCTAssertEqual(project.composition.tracks.filter { $0.name.hasPrefix("Text ") }.count, 1)
    }

    func testTextTrackCreatesSecondTrackWhenFirstHoldsMedia() {
        var project = Project.empty(schemaVersion: 2)
        let asset = MediaAsset(
            name: "Sunrise",
            kind: .video,
            policy: .linked,
            storagePath: "/Movies/sunrise.mp4",
            duration: .exact(3000, over: Composition.timescale),
            pixelWidth: 1920,
            pixelHeight: 1080,
            frameRate: .fps30,
            addedAt: Date()
        )
        project.addAsset(asset)
        let mediaClip = project.addTimelineClip(for: asset)

        // Simulate a shared track: the media's track carries a
        // text-track name but holds a media clip. The helper must not
        // reuse it, because its clips are not all text.
        let trackIndex = project.composition.tracks.firstIndex { track in
            track.clips.contains { $0.id == mediaClip.id }
        } ?? 0
        project.composition.tracks[trackIndex].name = "Text 1"

        let track = project.textTrack()

        XCTAssertEqual(track.name, "Text 2")
        XCTAssertFalse(track.clips.contains { $0.id == mediaClip.id })
        XCTAssertEqual(project.composition.tracks.filter { $0.name.hasPrefix("Text ") }.count, 2)
    }

    // MARK: Text clip placement

    func testAddTextClipPlacesFiveSecondClipAtPlayhead() {
        var project = Project.empty(schemaVersion: 2)
        let playhead = MediaTime.exact(2400, over: Composition.timescale) // 4 s

        let clip = project.addTextClip(at: playhead)

        XCTAssertEqual(clip.name, "Text")
        XCTAssertEqual(clip.timelineStart, playhead)
        XCTAssertEqual(clip.timelineDuration, MediaTime.exact(3000, over: Composition.timescale))
        XCTAssertEqual(clip.sourceIn, .zero)
        XCTAssertEqual(clip.sourceOut, clip.timelineDuration)
        XCTAssertTrue(clip.isText)
        XCTAssertFalse(clip.isPlayable)
        guard case .text(let source) = clip.source else {
            return XCTFail("Text clip must carry a text source")
        }
        XCTAssertEqual(source.text, "Text")
        XCTAssertEqual(source.typography, Typography.default)
    }

    func testAddTextClipExtendsCompositionDuration() {
        var project = Project.empty(schemaVersion: 2)
        let playhead = MediaTime.exact(9000, over: Composition.timescale) // 9 s + 5 s clip

        _ = project.addTextClip(at: playhead)

        XCTAssertEqual(project.composition.duration, MediaTime.exact(12000, over: Composition.timescale))
    }

    func testAddTextClipAvoidsOverlapByAppendingAfterLastClip() throws {
        var project = Project.empty(schemaVersion: 2)
        let first = project.addTextClip(at: .zero) // 0…5 s

        // Request the same spot: the second clip must land after the
        // first instead of overlapping it.
        let second = project.addTextClip(at: MediaTime.exact(600, over: Composition.timescale))

        XCTAssertEqual(second.timelineStart, first.timelineRange.end)
        XCTAssertNoThrow(try project.composition.validate())
    }

    func testAddTextClipNeverStartsNegative() {
        var project = Project.empty(schemaVersion: 2)

        let clip = project.addTextClip(at: MediaTime.exact(-600, over: Composition.timescale))

        XCTAssertEqual(clip.timelineStart, .zero)
    }

    // MARK: Clip helpers

    func testUpdateClipEditsOnlyTheTargetClip() {
        var project = Project.empty(schemaVersion: 2)
        let clip = project.addTextClip(at: .zero)

        let updated = project.updateClip(withID: clip.id) { clip in
            clip.name = "Intro Title"
        }

        XCTAssertEqual(updated?.name, "Intro Title")
        XCTAssertEqual(project.clip(withID: clip.id)?.clip.name, "Intro Title")
    }

    func testUpdateClipReturnsNilForUnknownID() {
        var project = Project.empty(schemaVersion: 2)

        let updated = project.updateClip(withID: UUID()) { _ in }

        XCTAssertNil(updated)
    }

    func testRemoveClipRemovesTargetAndKeepsTracks() {
        var project = Project.empty(schemaVersion: 2)
        let clip = project.addTextClip(at: .zero)
        let trackCount = project.composition.tracks.count

        let removed = project.removeClip(withID: clip.id)

        XCTAssertEqual(removed?.id, clip.id)
        XCTAssertEqual(project.composition.tracks.count, trackCount, "Tracks are structural and stay.")
        XCTAssertNil(project.clip(withID: clip.id))
    }

    func testRemoveClipReturnsNilForUnknownID() {
        var project = Project.empty(schemaVersion: 2)
        XCTAssertNil(project.removeClip(withID: UUID()))
    }

    func testTextProjectWithKeyframesValidates() throws {
        var project = Project.empty(schemaVersion: 2)
        let clip = project.addTextClip(at: .zero)
        _ = project.updateClip(withID: clip.id) { clip in
            clip.animations = [
                Animation(
                    property: .opacity,
                    keyframes: [
                        Keyframe(time: .zero, value: 0),
                        Keyframe(time: .exact(1200, over: 600), value: 1, interpolation: .easeInOut),
                    ]
                ),
                Animation(property: .scaleY, keyframes: [Keyframe(time: .exact(600, over: 600), value: 1.5)]),
            ]
        }

        try project.composition.validate() // must not throw
    }

    func testValidationRejectsInvalidAnimationInComposition() {
        var project = Project.empty(schemaVersion: 2)
        let clip = project.addTextClip(at: .zero)
        _ = project.updateClip(withID: clip.id) { clip in
            clip.animations = [Animation(property: .opacity, keyframes: [
                Keyframe(time: .zero, value: 3),
            ])]
        }

        XCTAssertThrowsError(try project.composition.validate()) { error in
            guard case ProjectValidationError.invalidAnimation = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testValidationRejectsInvalidTypography() {
        var project = Project.empty(schemaVersion: 2)
        let clip = project.addTextClip(at: .zero)
        _ = project.updateClip(withID: clip.id) { clip in
            clip.updateText { text in
                text.typography.fontSize = 0
            }
        }

        XCTAssertThrowsError(try project.composition.validate()) { error in
            guard case ProjectValidationError.invalidTypography = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    // MARK: Errors carry user-facing wording

    func testValidationErrorsDescribeTheProblem() {
        let typography = ProjectValidationError.invalidTypography("Font size must be positive.")
        XCTAssertEqual(
            typography.errorDescription,
            "Invalid typography: Font size must be positive.."
        )
        let animation = ProjectValidationError.invalidAnimation("Opacity keyframe value must be between 0 and 1.")
        XCTAssertEqual(
            animation.errorDescription,
            "Invalid animation: Opacity keyframe value must be between 0 and 1.."
        )
    }
}
