import SwiftUI
import XCTest
@testable import MotionStudio

/// Tests for the Milestone 3 environment behaviors: text clip
/// creation/selection/deletion, validated text edits, keyframe
/// toggling at the playhead, active overlay evaluation, and seeking
/// into text-only regions (roadmap Milestone 3).
@MainActor
final class TextLayerEnvironmentTests: XCTestCase {
    private var project: Project!
    private var environment: AppEnvironment!

    override func setUp() {
        project = Project.empty(schemaVersion: PackageFormat.currentSchemaVersion)
        environment = AppEnvironment()
        environment.attach(project: Binding(
            get: { [weak self] in self?.project ?? Project.empty(schemaVersion: PackageFormat.currentSchemaVersion) },
            set: { [weak self] in self?.project = $0 }
        ))
    }

    // MARK: Text creation and selection

    func testAddTextClipCreatesTrackClipAndSelectsIt() {
        environment.addTextClip()

        let track = project.composition.tracks.first
        XCTAssertEqual(track?.name, "Text 1")
        let clip = try! XCTUnwrap(track?.clips.first)
        XCTAssertTrue(clip.isText)
        XCTAssertEqual(environment.selectedClipID, clip.id)
        XCTAssertEqual(environment.playheadTime, clip.timelineStart)
    }

    func testSecondAddTextClipReusesTheTextTrack() {
        environment.addTextClip()
        environment.seekToCompositionTime(.exact(1800, over: 600), in: project) // inside the first clip
        environment.addTextClip()

        XCTAssertEqual(project.composition.tracks.filter { $0.name.hasPrefix("Text ") }.count, 1)
        XCTAssertEqual(project.composition.tracks.first?.clips.count, 2)
        // The second clip appends after the first instead of overlapping.
        let clips = project.composition.tracks.first!.clips
        XCTAssertEqual(clips[1].timelineStart, clips[0].timelineRange.end)
        XCTAssertNoThrow(try project.composition.validate())
    }

    func testSelectingTextClipKeepsVideoLoaded() {
        let asset = sampleAsset()
        project.addAsset(asset)
        environment.selectAsset(byID: asset.id)
        let loadedAsset = environment.selectedAssetID

        environment.addTextClip()

        XCTAssertEqual(environment.selectedAssetID, loadedAsset, "Text selection must not change media selection.")
    }

    func testDeleteSelectedClipRemovesIt() {
        environment.addTextClip()
        let clipID = environment.selectedClipID

        environment.deleteSelectedClip()

        XCTAssertNil(environment.selectedClipID)
        XCTAssertFalse(project.composition.tracks.contains { track in
            track.clips.contains { $0.id == clipID }
        })
    }

    // MARK: Validated text edits

    func testUpdateSelectedTextClipAppliesValidEdits() {
        environment.addTextClip()

        environment.updateSelectedTextClip { clip in
            clip.updateText { text in
                text.text = "Hello"
                text.typography.fontSize = 150
                text.typography.weight = .semibold
            }
        }

        let clip = project.composition.tracks.first!.clips.first!
        guard case .text(let source) = clip.source else {
            return XCTFail("Expected a text source")
        }
        XCTAssertEqual(source.text, "Hello")
        XCTAssertEqual(source.typography.fontSize, 150)
        XCTAssertEqual(source.typography.weight, .semibold)
    }

    func testInvalidTypographyEditIsRejectedWithoutApplying() {
        environment.addTextClip()
        let original = project.composition.tracks.first!.clips.first!

        environment.updateSelectedTextClip { clip in
            clip.updateText { text in
                text.typography.fontSize = 0
            }
        }

        let clip = project.composition.tracks.first!.clips.first!
        XCTAssertEqual(clip.id, original.id)
        XCTAssertEqual(clip.timelineStart, original.timelineStart)
        XCTAssertEqual(
            try! extractTypography(from: clip).fontSize,
            try! extractTypography(from: original).fontSize,
            "The invalid edit must not apply."
        )
        XCTAssertNotNil(environment.presentedError, "Rejection must be reported.")
    }

    func testUpdatesOnNonTextClipsAreIgnored() {
        let asset = sampleAsset()
        project.addAsset(asset)
        var updated = project!
        let mediaClip = updated.addTimelineClip(for: asset)
        project = updated
        environment.selectClip(mediaClip, in: project)

        environment.updateSelectedTextClip { clip in
            clip.name = "Should not apply"
        }

        let current = project.clip(withID: mediaClip.id)?.clip
        XCTAssertNotEqual(current?.name, "Should not apply")
    }

    // MARK: Keyframe editing

    func testToggleKeyframeAddsAnimationSeededWithStaticValue() {
        environment.addTextClip()
        environment.seekToCompositionTime(.exact(1200, over: Composition.timescale), in: project)

        environment.toggleKeyframe(for: .opacity)

        let clip = project.composition.tracks.first!.clips.first!
        let animation = clip.animation(for: .opacity)
        XCTAssertEqual(animation?.keyframes.count, 1)
        // Clip-local time 2 s, value from the static base opacity 1.
        XCTAssertEqual(animation?.keyframes.first?.time, .exact(1200, over: Composition.timescale))
        XCTAssertEqual(animation?.keyframes.first?.value, 1)
        XCTAssertEqual(animation?.keyframes.first?.interpolation, .linear)
    }

    func testToggleKeyframeAtSameTimeRemovesIt() {
        environment.addTextClip()
        environment.toggleKeyframe(for: .scaleX)

        environment.toggleKeyframe(for: .scaleX)

        let clip = project.composition.tracks.first!.clips.first!
        XCTAssertNil(clip.animation(for: .scaleX), "Toggling twice at the same time removes the keyframe.")
    }

    func testToggleKeyframeTwiceAtDifferentTimesAddsTwo() {
        environment.addTextClip()
        environment.toggleKeyframe(for: .scaleY)
        environment.seekToCompositionTime(.exact(1200, over: Composition.timescale), in: project)
        environment.toggleKeyframe(for: .scaleY)

        let clip = project.composition.tracks.first!.clips.first!
        XCTAssertEqual(clip.animation(for: .scaleY)?.keyframes.count, 2)
        XCTAssertNoThrow(try clip.validate())
    }

    func testNewKeyframeCapturesEvaluatedValueNotStatic() throws {
        environment.addTextClip()
        environment.toggleKeyframe(for: .opacity) // keyframe at 0, value = base 1
        environment.updateKeyframe(for: .opacity, at: .zero, value: 0)
        environment.seekToCompositionTime(.exact(1800, over: 600), in: project) // 3 s
        environment.toggleKeyframe(for: .opacity) // holds 0 at 3 s
        environment.updateKeyframe(for: .opacity, at: .exact(1800, over: 600), value: 1)
        environment.seekToCompositionTime(.exact(900, over: 600), in: project) // 1.5 s
        environment.toggleKeyframe(for: .opacity)

        // The new keyframe sits at clip-local 1.5 s, halfway between
        // the keyframes at 0 and 3 s (values 0 and 1): it must capture
        // the evaluated 0.5, not the static base of 1.
        let clip = project.composition.tracks.first!.clips.first!
        let animation = try XCTUnwrap(clip.animation(for: .opacity))
        XCTAssertEqual(animation.keyframes.count, 3)
        let captured = try XCTUnwrap(animation.keyframes.first { $0.time == .exact(900, over: 600) })
        XCTAssertEqual(captured.value, 0.5, accuracy: 1e-9)
    }

    func testRemoveKeyframeDeletesOnlyTheTargetKeyframe() {
        environment.addTextClip()
        environment.toggleKeyframe(for: .opacity)
        environment.seekToCompositionTime(.exact(1200, over: 600), in: project)
        environment.toggleKeyframe(for: .opacity)

        environment.removeKeyframe(for: .opacity, at: .zero)

        let clip = project.composition.tracks.first!.clips.first!
        XCTAssertEqual(clip.animation(for: .opacity)?.keyframes.map(\.time), [.exact(1200, over: 600)])
    }

    func testUpdateKeyframeChangesValueAndInterpolation() {
        environment.addTextClip()
        environment.toggleKeyframe(for: .scaleX)

        environment.updateKeyframe(for: .scaleX, at: .zero, value: 2.5, interpolation: .easeInOut)

        let clip = project.composition.tracks.first!.clips.first!
        let keyframe = clip.animation(for: .scaleX)?.keyframes.first
        XCTAssertEqual(keyframe?.value, 2.5)
        XCTAssertEqual(keyframe?.interpolation, .easeInOut)
    }

    func testUpdateKeyframeRejectsInvalidValue() {
        environment.addTextClip()
        environment.toggleKeyframe(for: .opacity)

        environment.updateKeyframe(for: .opacity, at: .zero, value: 7)

        let clip = project.composition.tracks.first!.clips.first!
        XCTAssertEqual(clip.animation(for: .opacity)?.keyframes.first?.value, 1, "Invalid value must be rejected.")
        XCTAssertNotNil(environment.presentedError)
    }

    func testToggleAnimationAddsAndRemoves() {
        environment.addTextClip()

        environment.toggleAnimation(for: .opacity)
        var clip = project.composition.tracks.first!.clips.first!
        XCTAssertEqual(clip.animation(for: .opacity)?.keyframes.count, 1)

        environment.toggleAnimation(for: .opacity)
        clip = project.composition.tracks.first!.clips.first!
        XCTAssertNil(clip.animation(for: .opacity))
    }

    func testAddAnimationDoesNotDuplicate() {
        environment.addTextClip()
        environment.addAnimation(for: .scaleX)
        environment.addAnimation(for: .scaleX)

        let clip = project.composition.tracks.first!.clips.first!
        XCTAssertEqual(clip.animations.filter { $0.property == .scaleX }.count, 1)
    }

    // MARK: Active overlays

    func testActiveTextOverlaysContainsOnlyClipsUnderThePlayhead() {
        environment.addTextClip()
        let clip = project.composition.tracks.first!.clips.first!

        environment.seekToCompositionTime(clip.timelineStart, in: project)
        XCTAssertEqual(environment.activeTextOverlays(in: project).count, 1)

        environment.seekToCompositionTime(clip.timelineRange.end, in: project)
        XCTAssertEqual(environment.activeTextOverlays(in: project).count, 0)
    }

    func testActiveTextOverlaysCarriesEvaluatedValues() {
        environment.addTextClip()
        environment.toggleKeyframe(for: .opacity) // keyframe at clip start, value = base 1
        environment.updateKeyframe(for: .opacity, at: .zero, value: 0.25)

        let clip = project.composition.tracks.first!.clips.first!
        environment.seekToCompositionTime(clip.timelineStart, in: project)

        let overlay = try! XCTUnwrap(environment.activeTextOverlays(in: project).first)
        XCTAssertEqual(overlay.clip.id, clip.id)
        XCTAssertEqual(overlay.values.opacity, 0.25, accuracy: 1e-9)
    }

    // MARK: Seeking around text

    func testSeekIntoTextOnlyRegionPausesAndMovesPlayhead() {
        environment.addTextClip()
        let clip = project.composition.tracks.first!.clips.first!

        // Seek to the middle of the text clip.
        let middle = clip.timelineStart + MediaTime.exact(1200, over: 600)
        environment.seekToCompositionTime(middle, in: project)

        XCTAssertEqual(environment.playheadTime, middle)
        XCTAssertEqual(environment.selectedClipID, clip.id, "Selection must stay on the text clip.")
    }

    func testSeekOverlappingVideoAndTextKeepsVideoDriven() {
        let asset = sampleAsset()
        project.addAsset(asset)
        var updated = project!
        let mediaClip = updated.addTimelineClip(for: asset)
        project = updated

        environment.addTextClip() // text at the playhead (0), video clip also at 0
        environment.selectClip(mediaClip, in: project)

        // Seek inside the overlap: the video clip must drive seeking.
        let inside = MediaTime.exact(600, over: 600)
        environment.seekToCompositionTime(inside, in: project)

        XCTAssertEqual(environment.selectedClipID, mediaClip.id)
        XCTAssertEqual(environment.playheadTime, inside)
    }

    // MARK: Fixtures

    private func sampleAsset() -> MediaAsset {
        MediaAsset(
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
    }

    private func extractTypography(from clip: Clip) throws -> Typography {
        guard case .text(let source) = clip.source else {
            throw XCTSkip("Not a text clip")
        }
        return source.typography
    }
}
