import AVFoundation
import XCTest
@testable import MotionStudio

/// Tests for media inspection during import.
final class MediaImporterTests: XCTestCase {
    private let importer = MediaImporter()

    func testInspectExtractsMetadataFromValidVideo() async throws {
        let url = try await MediaFixtures.makeVideo(lengthSeconds: 0.5)
        defer { try? FileManager.default.removeItem(at: url) }

        let info = try await importer.inspect(url: url)

        XCTAssertEqual(info.videoTrackCount, 1)
        XCTAssertEqual(info.audioTrackCount, 0)
        XCTAssertEqual(info.naturalSize.width, 32, accuracy: 0.5)
        XCTAssertEqual(info.naturalSize.height, 32, accuracy: 0.5)
        XCTAssertEqual(info.durationSeconds, 0.5, accuracy: 0.15)
        XCTAssertEqual(info.videoCodec, "avc1")
    }

    func testRejectsMissingFile() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("motionstudio-missing-\(UUID().uuidString).mp4")

        do {
            _ = try await importer.inspect(url: url)
            XCTFail("Expected a fileMissing rejection")
        } catch let error as MediaImportError {
            guard case .fileMissing = error else {
                XCTFail("Unexpected error: \(error)")
                return
            }
        }
    }

    func testRejectsFileWithUnsupportedExtension() async throws {
        let url = try MediaFixtures.makeTextFile(named: "motionstudio-\(UUID().uuidString).txt")
        defer { try? FileManager.default.removeItem(at: url) }

        do {
            _ = try await importer.inspect(url: url)
            XCTFail("Expected an unsupportedFormat rejection")
        } catch let error as MediaImportError {
            guard case .unsupportedFormat = error else {
                XCTFail("Unexpected error: \(error)")
                return
            }
        }
    }

    func testRejectsNonVideoFileWithSupportedExtension() async throws {
        let url = try MediaFixtures.makeTextFile(named: "motionstudio-\(UUID().uuidString).mp4")
        defer { try? FileManager.default.removeItem(at: url) }

        do {
            _ = try await importer.inspect(url: url)
            XCTFail("Expected a rejection for non-video content")
        } catch is MediaImportError {
            // Acceptable: unsupported format or failed metadata load.
        }
    }
}
