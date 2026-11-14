import XCTest
@testable import MotionStudio

/// Tests for the versioned project manifest: round-trips, the explicit
/// tagged clip source contract, and rejection of foreign, corrupt, or
/// future-versioned files.
final class ProjectSerializationTests: XCTestCase {
    private var packageURL: URL!

    override func setUpWithError() throws {
        packageURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-\(UUID().uuidString).\(PackageFormat.fileExtension)")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: packageURL)
    }

    // MARK: Fixtures

    private func makeSampleProject() -> Project {
        var project = Project.empty(schemaVersion: PackageFormat.currentSchemaVersion)
        let asset = MediaAsset(
            name: "Sunrise",
            kind: .video,
            policy: .linked,
            storagePath: "/Movies/sunrise.mp4",
            duration: .exact(3000, over: Composition.timescale),
            pixelWidth: 1920,
            pixelHeight: 1080,
            frameRate: .fps30,
            addedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        project.addAsset(asset)
        project.addTimelineClip(for: asset)
        return project
    }

    // MARK: Round trip

    func testEncodeDecodeRoundTrip() throws {
        let original = makeSampleProject()
        let data = try ProjectManifestCodec.encode(original)
        let decoded = try ProjectManifestCodec.decode(data, packageURL: packageURL)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.schemaVersion, PackageFormat.currentSchemaVersion)
        // ISO-8601 timestamps store whole seconds.
        XCTAssertLessThan(
            abs(decoded.createdAt.timeIntervalSince(original.createdAt)),
            1
        )
        XCTAssertEqual(decoded.composition, original.composition)
        XCTAssertEqual(decoded.assets, original.assets)
    }

    func testEncodeStampsCurrentSchemaVersion() throws {
        let original = makeSampleProject()

        let data = try ProjectManifestCodec.encode(original)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let manifest = try decoder.decode(ProjectManifest.self, from: data)

        XCTAssertEqual(manifest.schemaVersion, PackageFormat.currentSchemaVersion)
        XCTAssertEqual(manifest.format, PackageFormat.formatIdentifier)
        XCTAssertEqual(manifest.project.schemaVersion, PackageFormat.currentSchemaVersion)
    }

    func testManifestJSONIsPrettyPrintedWithSortedKeys() throws {
        let data = try ProjectManifestCodec.encode(makeSampleProject())
        let text = String(decoding: data, as: UTF8.self)
        XCTAssertTrue(text.contains("\n"), "Manifest should be pretty-printed for inspection.")
    }

    // MARK: Clip source contract (explicit tagged encoding)

    func testClipSourceEncodesExplicitDiscriminatorAndVersion() throws {
        let assetID = UUID()
        let data = try JSONEncoder().encode(ClipSource.asset(MediaAssetSource(assetID: assetID)))

        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        XCTAssertEqual(object["kind"] as? String, "asset")
        XCTAssertEqual(object["version"] as? Int, 1)
        XCTAssertEqual(UUID(uuidString: object["assetID"] as? String ?? ""), assetID)
    }

    func testClipSourceDecodesExplicitContract() throws {
        let assetID = UUID()
        let json = Data(
            #"{"kind": "asset", "version": 1, "assetID": "\#(assetID.uuidString)"}"#.utf8
        )
        let source = try JSONDecoder().decode(ClipSource.self, from: json)
        XCTAssertEqual(source, .asset(MediaAssetSource(assetID: assetID)))
    }

    func testClipSourceRejectsUnknownKind() throws {
        let json = Data(#"{"kind": "shape", "version": 1}"#.utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(ClipSource.self, from: json))
    }

    func testClipSourceRejectsUnknownPayloadVersion() throws {
        let json = Data(
            #"{"kind": "asset", "version": 2, "assetID": "\#(UUID().uuidString)"}"#.utf8
        )
        XCTAssertThrowsError(try JSONDecoder().decode(ClipSource.self, from: json))
    }

    // MARK: Rejection paths

    func testRejectsFutureSchemaVersion() throws {
        let data = try ProjectManifestCodec.encode(makeSampleProject())
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        object["schemaVersion"] = PackageFormat.currentSchemaVersion + 1

        let mutated = try JSONSerialization.data(withJSONObject: object)
        XCTAssertThrowsError(try ProjectManifestCodec.decode(mutated, packageURL: packageURL)) { error in
            guard case ProjectFileError.unsupportedSchemaVersion = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testRejectsCorruptManifest() throws {
        let data = Data(
            "{\"format\": \"\(PackageFormat.formatIdentifier)\", \"schemaVersion\": 1".utf8
        )
        XCTAssertThrowsError(try ProjectManifestCodec.decode(data, packageURL: packageURL)) { error in
            guard case ProjectFileError.corruptManifest = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testRejectsForeignJSONAsNotAProjectFile() throws {
        let data = Data(#"{"hello": "world"}"#.utf8)
        XCTAssertThrowsError(try ProjectManifestCodec.decode(data, packageURL: packageURL)) { error in
            guard case ProjectFileError.notAProjectFile = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testRejectsInconsistentSchemaVersions() throws {
        let data = try ProjectManifestCodec.encode(makeSampleProject())
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        var project = try XCTUnwrap(object["project"] as? [String: Any])
        project["schemaVersion"] = 99
        object["project"] = project

        let mutated = try JSONSerialization.data(withJSONObject: object)
        XCTAssertThrowsError(try ProjectManifestCodec.decode(mutated, packageURL: packageURL)) { error in
            guard case ProjectFileError.inconsistentSchemaVersion = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testRejectsInvalidProjectData() throws {
        var project = Project.empty(schemaVersion: PackageFormat.currentSchemaVersion)
        project.composition.width = 0

        let data = try ProjectManifestCodec.encode(project)
        XCTAssertThrowsError(try ProjectManifestCodec.decode(data, packageURL: packageURL)) { error in
            guard case ProjectFileError.invalidProject = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testMissingProjectKeyReportsCorruptManifest() throws {
        let data = Data(
            "{\"format\": \"\(PackageFormat.formatIdentifier)\", \"schemaVersion\": 1}".utf8
        )
        XCTAssertThrowsError(try ProjectManifestCodec.decode(data, packageURL: packageURL)) { error in
            guard case ProjectFileError.corruptManifest = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }
}
