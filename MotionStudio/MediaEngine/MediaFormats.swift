import Foundation
import UniformTypeIdentifiers

/// The explicitly supported initial media format set (roadmap Milestone 1).
///
/// Kept deliberately small: QuickTime MOV and MPEG-4 MP4/M4V containers,
/// which AVFoundation handles reliably on every supported Mac. Grow this
/// set only with testing.
enum MediaFormats {
    nonisolated static let fileExtensions: Set<String> = ["mov", "mp4", "m4v"]

    /// Human-readable summary used in UI and documentation.
    nonisolated static let displaySummary = "MOV, MP4, M4V"

    nonisolated static func supportsFileExtension(_ pathExtension: String) -> Bool {
        fileExtensions.contains(pathExtension.lowercased())
    }

    /// Content types used to filter the open panel.
    nonisolated static var allowedContentTypes: [UTType] {
        var types: [UTType] = [.quickTimeMovie, .mpeg4Movie]
        if let m4v = UTType(filenameExtension: "m4v") {
            types.append(m4v)
        }
        return types
    }
}
