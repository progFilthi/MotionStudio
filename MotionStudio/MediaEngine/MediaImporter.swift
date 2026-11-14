import AVFoundation
import Foundation
import UniformTypeIdentifiers
import os

/// Errors raised while inspecting media for import. Every rejection is
/// typed and user-explainable (architecture §15).
nonisolated enum MediaImportError: Error, LocalizedError {
    case fileMissing(URL)
    case unreadable(URL)
    case unsupportedFormat(String)
    case noMediaTracks(URL)
    case metadataLoadingFailed(URL, String)

    var errorDescription: String? {
        switch self {
        case .fileMissing: "File not found"
        case .unreadable: "The file could not be read"
        case .unsupportedFormat: "Unsupported video format"
        case .noMediaTracks: "No usable media in file"
        case .metadataLoadingFailed: "Media information could not be read"
        }
    }

    var failureReason: String? {
        switch self {
        case .fileMissing(let url):
            return "'\(url.lastPathComponent)' no longer exists or was moved."
        case .unreadable(let url):
            return "'\(url.lastPathComponent)' could not be opened. The file may be damaged or access may be denied."
        case .unsupportedFormat(let detail):
            return "\(detail) Supported formats: \(MediaFormats.displaySummary)."
        case .noMediaTracks(let url):
            return "'\(url.lastPathComponent)' does not contain any video or audio tracks."
        case .metadataLoadingFailed(_, let detail):
            return detail
        }
    }
}

/// Inspects user-selected media files before they enter the library.
///
/// Runs off the main actor; AVFoundation loads are asynchronous. Never
/// silently discards failures — every rejection produces a typed error that
/// surfaces through the application error-reporting path.
nonisolated struct MediaImporter: Sendable {
    func inspect(url: URL) async throws -> ImportedMediaInfo {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: url.path) else {
            throw MediaImportError.fileMissing(url)
        }
        guard fileManager.isReadableFile(atPath: url.path) else {
            throw MediaImportError.unreadable(url)
        }
        guard MediaFormats.supportsFileExtension(url.pathExtension) else {
            throw MediaImportError.unsupportedFormat(
                "'\(url.lastPathComponent)' is not a MOV, MP4, or M4V file."
            )
        }

        let asset = AVURLAsset(url: url)
        do {
            let playable = try await asset.load(.isPlayable)
            guard playable else {
                throw MediaImportError.unsupportedFormat(
                    "'\(url.lastPathComponent)' cannot be played on this Mac."
                )
            }

            let tracks = try await asset.load(.tracks)
            let videoTracks = tracks.filter { $0.mediaType == .video }
            let audioTracks = tracks.filter { $0.mediaType == .audio }
            guard !videoTracks.isEmpty || !audioTracks.isEmpty else {
                throw MediaImportError.noMediaTracks(url)
            }

            let duration = try await asset.load(.duration)

            var naturalSize = CGSize.zero
            var videoCodec: String?
            var frameRate: Float?
            if let videoTrack = videoTracks.first {
                let size = try await videoTrack.load(.naturalSize)
                let transform = try await videoTrack.load(.preferredTransform)
                let transformed = size.applying(transform)
                naturalSize = CGSize(width: abs(transformed.width), height: abs(transformed.height))

                if let descriptions = try? await videoTrack.load(.formatDescriptions),
                   let first = descriptions.first {
                    videoCodec = MediaImporter.fourCCString(CMFormatDescriptionGetMediaSubType(first))
                }

                frameRate = try? await videoTrack.load(.nominalFrameRate)
            }

            return ImportedMediaInfo(
                url: url,
                durationSeconds: duration.seconds,
                naturalSize: naturalSize,
                videoTrackCount: videoTracks.count,
                audioTrackCount: audioTracks.count,
                frameRate: frameRate,
                videoCodec: videoCodec
            )
        } catch let error as MediaImportError {
            throw error
        } catch {
            AppLog.media.error(
                "Metadata load failed for '\(url.lastPathComponent, privacy: .public)': \(String(describing: error), privacy: .public)"
            )
            throw MediaImportError.metadataLoadingFailed(
                url,
                "The media information for '\(url.lastPathComponent)' could not be read."
            )
        }
    }

    private static func fourCCString(_ code: FourCharCode) -> String {
        let bytes = [
            UInt8((code >> 24) & 0xFF),
            UInt8((code >> 16) & 0xFF),
            UInt8((code >> 8) & 0xFF),
            UInt8(code & 0xFF),
        ]
        return String(bytes: bytes, encoding: .ascii) ?? String(code)
    }
}
