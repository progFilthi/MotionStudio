import XCTest
@testable import MotionStudio

/// Tests for the Milestone 3 schema additions: typed text sources,
/// keyframe animations, decode defaults, and the v1 → v2 migration
/// (architecture §6.3).
final class AnimationSerializationTests: XCTestCase {
    private var packageURL: URL!

    override func setUpWithError() throws {
        packageURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-\(UUID().uuidString).\(PackageFormat.fileExtension)")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: packageURL)
    }

    // MARK: Text source contract

    func testTextSourceEncodesExplicitContract() throws {
        let source = ClipSource.text(TextSource(
            text: "Hello",
            typography: Typography(fontSize: 64, weight: .bold)
        ))
        let data = try JSONEncoder().encode(source)

        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(object["kind"] as? String, "text")
        XCTAssertEqual(object["version"] as? Int, 1)
        XCTAssertEqual(object["text"] as? String, "Hello")

        let typography = try XCTUnwrap(object["typography"] as? [String: Any])
        XCTAssertEqual(typography["fontSize"] as? Double, 64)
        XCTAssertEqual(typography["weight"] as? String, "bold")
    }

    func testTextSourceDecodesExplicitContract() throws {
        let json = Data(
            #"{"kind": "text", "version": 1, "text": "Hello", "typography": {"fontSize": 48, "weight": "semibold"}}"#.utf8
        )
        let source = try JSONDecoder().decode(ClipSource.self, from: json)

        guard case .text(let text) = source else {
            return XCTFail("Expected a text source, got \(source)")
        }
        XCTAssertEqual(text.text, "Hello")
        XCTAssertEqual(text.typography.fontSize, 48)
        XCTAssertEqual(text.typography.weight, .semibold)
        // Keys the payload omits fall back to the documented defaults.
        XCTAssertEqual(text.typography.fontName, "System")
        XCTAssertEqual(text.typography.fillColor, .white)
        XCTAssertEqual(text.typography.alignment, .center)
        XCTAssertEqual(text.typography.tracking, 0)
    }

    func testTextSourceRejectsUnknownPayloadVersion() throws {
        let json = Data(#"{"kind": "text", "version": 2, "text": "Hello"}"#.utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(ClipSource.self, from: json))
    }

    func testTypographyRejectsNonPositiveFontSizeOnDecode() throws {
        let json = Data(#"{"fontSize": 0}"#.utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(Typography.self, from: json))
    }

    func testTypographyDefaultsOnDecode() throws {
        let source = try JSONDecoder().decode(Typography.self, from: Data("{}".utf8))
        XCTAssertEqual(source, Typography.default)
    }

    // MARK: Animation + keyframes

    func testAnimationRoundTripPreservesKeyframes() throws {
        let animation = Animation(
            property: .scaleY,
            keyframes: [
                Keyframe(time: .exact(600, over: 600), value: 0.5),
                Keyframe(time: .exact(1800, over: 600), value: 2.5, interpolation: .easeInOut),
            ]
        )

        let data = try JSONEncoder().encode(animation)
        let decoded = try JSONDecoder().decode(Animation.self, from: data)
        XCTAssertEqual(decoded, animation)
    }

    func testKeyframeDefaultsToLinearWhenInterpolationMissing() throws {
        let json = Data(#"{"time": {"value": 600, "timescale": 600}, "value": 0.5}"#.utf8)
        let keyframe = try JSONDecoder().decode(Keyframe.self, from: json)
        XCTAssertEqual(keyframe.interpolation, .linear)
    }

    func testClipWithoutAnimationsDecodesWithEmptyAnimations() throws {
        // A Milestone 2-shaped clip: no `animations` key at all.
        let clipID = UUID()
        let json = Data(#"""
        {"id": "\#(clipID.uuidString)", "name": "Clip",
         "source": {"kind": "asset", "version": 1, "assetID": "\#(UUID().uuidString)"},
         "timelineStart": {"value": 0, "timescale": 600},
         "timelineDuration": {"value": 600, "timescale": 600},
         "sourceIn": {"value": 0, "timescale": 600},
         "sourceOut": {"value": 600, "timescale": 600}}
        """#.utf8)
        let clip = try JSONDecoder().decode(Clip.self, from: json)
        XCTAssertEqual(clip.animations, [])
        XCTAssertFalse(clip.isText)
        XCTAssertTrue(clip.isPlayable)
    }

    func testUnknownAnimatablePropertyNameIsRejected() throws {
        let json = Data(#"{"property": "warp", "keyframes": []}"#.utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(Animation.self, from: json))
    }

    // MARK: Validation

    func testAnimationRejectsNegativeKeyframeTime() {
        let animation = Animation(property: .opacity, keyframes: [
            Keyframe(time: .exact(-300, over: 600), value: 0.5),
        ])
        XCTAssertThrowsError(try animation.validate())
    }

    func testAnimationRejectsOutOfRangOpacity() {
        let animation = Animation(property: .opacity, keyframes: [
            Keyframe(time: .zero, value: 1.5),
        ])
        XCTAssertThrowsError(try animation.validate())
    }

    func testAnimationRejectsNegativeScale() {
        let animation = Animation(property: .scaleX, keyframes: [
            Keyframe(time: .zero, value: -0.1),
        ])
        XCTAssertThrowsError(try animation.validate())
    }

    func testAnimationAcceptsZeroScale() throws {
        let animation = Animation(property: .scaleX, keyframes: [
            Keyframe(time: .zero, value: 0),
        ])
        try animation.validate() // must not throw
    }

    func testAnimationRejectsDuplicateKeyframeTimes() {
        var animation = Animation(property: .opacity, keyframes: [
            Keyframe(time: .exact(600, over: 600), value: 0.2),
        ])
        XCTAssertThrowsError(try animation.insert(Keyframe(time: .exact(600, over: 600), value: 0.8)))
        // Sorted insertion keeps times strictly increasing.
        XCTAssertEqual(animation.keyframes.count, 1)
    }

    func testInsertKeepsKeyframesSortedByTime() throws {
        var animation = Animation(property: .opacity, keyframes: [
            Keyframe(time: .exact(600, over: 600), value: 0.2),
        ])
        try animation.insert(Keyframe(time: .exact(1800, over: 600), value: 0.6))
        try animation.insert(Keyframe(time: .exact(1200, over: 600), value: 0.4))

        XCTAssertEqual(animation.keyframes.map(\.value), [0.2, 0.4, 0.6])
    }

    func testKeyframeHitTestingUsesTolerance() {
        let animation = Animation(property: .opacity, keyframes: [
            Keyframe(time: .exact(600, over: 600), value: 0.2),
        ])
        // Half a 30 fps frame = 1/60 s = 10 units at timescale 600.
        let tolerance = FrameRate.fps30.halfFrameDuration
        XCTAssertEqual(tolerance, .exact(1, over: 60))

        // Exactly at the keyframe: hit.
        XCTAssertNotNil(animation.keyframe(near: .exact(600, over: 600), tolerance: tolerance))
        // Within the half-frame tolerance (tolerance is 10 units at
        // timescale 600): hit.
        XCTAssertNotNil(animation.keyframe(near: .exact(605, over: 600), tolerance: tolerance))
        // A full frame away (20 units): miss.
        XCTAssertNil(animation.keyframe(near: .exact(620, over: 600), tolerance: tolerance))
    }

    // MARK: v1 → v2 migration

    func testV1ManifestWithoutTextOrAnimationsMigratesToV2() throws {
        // Hand-built Milestone 2 manifest: schemaVersion 1 everywhere,
        // no text sources, no animations key.
        let assetID = UUID()
        let manifestJSON = Data(#"""
        {
          "format": "\#(PackageFormat.formatIdentifier)",
          "schemaVersion": 1,
          "project": {
            "schemaVersion": 1,
            "id": "\#(UUID().uuidString)",
            "name": "Legacy",
            "createdAt": "2026-01-01T00:00:00Z",
            "updatedAt": "2026-01-01T00:00:00Z",
            "composition": {
              "id": "\#(UUID().uuidString)",
              "name": "Main Composition",
              "width": 1920,
              "height": 1080,
              "frameRate": {"numerator": 30, "denominator": 1},
              "duration": {"value": 6000, "timescale": 600},
              "background": {"r": 0, "g": 0, "b": 0, "a": 1},
              "tracks": [
                {"id": "\#(UUID().uuidString)", "name": "Video 1", "kind": "video",
                 "isVisible": true, "isLocked": false, "clips": []}
              ]
            },
            "assets": [
              {"id": "\#(assetID.uuidString)", "name": "Sunrise", "kind": "video",
               "policy": "linked", "storagePath": "/Movies/sunrise.mp4",
               "duration": {"value": 3000, "timescale": 600},
               "pixelWidth": 1920, "pixelHeight": 1080,
               "frameRate": {"numerator": 30, "denominator": 1},
               "addedAt": "2026-01-01T00:00:00Z"}
            ]
          }
        }
        """#.utf8)

        let decoded = try ProjectManifestCodec.decode(manifestJSON, packageURL: packageURL)

        XCTAssertEqual(decoded.schemaVersion, PackageFormat.currentSchemaVersion)
        XCTAssertEqual(decoded.name, "Legacy")
        XCTAssertEqual(decoded.assets.first?.id, assetID)
        XCTAssertEqual(decoded.composition.tracks.first?.clips.count, 0)
    }

    func testV1ManifestContainingV2PayloadDataMigratesCleanly() throws {
        // Encode a modern project, then downgrade both schema versions
        // to 1: the migration must accept it (identity step) and stamp
        // the result back to the current version.
        let modern = try ProjectManifestCodec.encode(makeTextProject())
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: modern) as? [String: Any])
        object["schemaVersion"] = 1
        var projectObject = try XCTUnwrap(object["project"] as? [String: Any])
        projectObject["schemaVersion"] = 1
        object["project"] = projectObject
        let downgraded = try JSONSerialization.data(withJSONObject: object)

        let decoded = try ProjectManifestCodec.decode(downgraded, packageURL: packageURL)

        XCTAssertEqual(decoded.schemaVersion, PackageFormat.currentSchemaVersion)
        XCTAssertEqual(decoded.composition.tracks.count, 2) // text track + video track
        XCTAssertTrue(decoded.composition.tracks[0].clips[0].isText)
    }

    func testTextProjectRoundTripsThroughTheManifest() throws {
        let original = makeTextProject()
        let data = try ProjectManifestCodec.encode(original)
        let decoded = try ProjectManifestCodec.decode(data, packageURL: packageURL)

        XCTAssertEqual(decoded.composition, original.composition)

        let clip = decoded.composition.tracks[0].clips[0]
        guard case .text(let source) = clip.source else {
            return XCTFail("Expected a text source after the round trip")
        }
        XCTAssertEqual(source.text, "Title")
        XCTAssertEqual(source.typography.fontSize, 120)
        XCTAssertEqual(clip.animation(for: .opacity)?.keyframes.count, 2)
        XCTAssertEqual(clip.animation(for: .opacity)?.keyframes[1].interpolation, .easeInOut)
    }

    // MARK: Fixtures

    private func makeTextProject() -> Project {
        var project = Project.empty(schemaVersion: PackageFormat.currentSchemaVersion)
        let clip = project.addTextClip(at: .zero)
        let _ = project.updateClip(withID: clip.id) { clip in
            clip.name = "Title"
            clip.updateText { text in
                text.text = "Title"
                text.typography.fontSize = 120
            }
            clip.animations = [Animation(
                property: .opacity,
                keyframes: [
                    Keyframe(time: .zero, value: 0),
                    Keyframe(time: .exact(1200, over: 600), value: 1, interpolation: .easeInOut),
                ]
            )]
        }
        return project
    }
}
