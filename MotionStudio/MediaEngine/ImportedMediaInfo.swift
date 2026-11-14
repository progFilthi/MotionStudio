import Foundation

/// Metadata snapshot for one imported media file.
nonisolated struct ImportedMediaInfo: Equatable, Sendable {
    let url: URL

    /// Duration in seconds for display. The authoritative rational time
    /// model (`MediaTime`) arrives with the project model in Milestone 2.
    let durationSeconds: Double

    /// Display dimensions in pixels, with rotation metadata applied.
    let naturalSize: CGSize
    let videoTrackCount: Int
    let audioTrackCount: Int

    /// Four-character codec code of the first video track, if any.
    let videoCodec: String?
}
