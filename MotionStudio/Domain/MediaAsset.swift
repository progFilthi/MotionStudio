import Foundation

/// The kind of content an imported media asset provides.
nonisolated enum MediaAssetKind: String, Codable, Hashable, Sendable {
    case video
    case audio
}

/// How a media asset's file is stored relative to the project package
/// (architecture §6.2).
///
/// The distinction is explicit in the project format:
///
/// - `.linked`: the project references the user-selected file at its
///   original location; `storagePath` is an absolute path.
/// - `.copied`: the file lives inside the project package; `storagePath`
///   is package-relative, such as `assets/<uuid>-clip.mp4`. Resolution
///   needs the package base URL.
///
/// Milestone 2 imports are linked. Copy-on-import is a media-management
/// milestone; both cases resolve correctly so the format already
/// distinguishes them and never needs a lossy migration.
nonisolated enum MediaReferencePolicy: String, Codable, Hashable, Sendable {
    case linked
    case copied
}

/// One imported media file registered in the project.
///
/// Assets are referenced by stable UUID (architecture §5.2) — never by
/// array index or path — from clip sources.
nonisolated struct MediaAsset: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    var name: String
    var kind: MediaAssetKind

    /// How the file is stored (see `MediaReferencePolicy`).
    var policy: MediaReferencePolicy

    /// Absolute file path for linked assets, or a package-relative path
    /// such as `assets/<uuid>-name.mp4` for copied assets.
    var storagePath: String

    /// Rational duration of the media.
    var duration: MediaTime

    /// Display dimensions in pixels, rotation applied. Zero for
    /// audio-only assets.
    var pixelWidth: Int
    var pixelHeight: Int

    /// Rational frame rate of the video track, when known.
    var frameRate: FrameRate?

    var addedAt: Date

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case kind
        case policy
        case storagePath
        case duration
        case pixelWidth
        case pixelHeight
        case frameRate
        case addedAt
    }

    init(
        id: UUID = UUID(),
        name: String,
        kind: MediaAssetKind,
        policy: MediaReferencePolicy,
        storagePath: String,
        duration: MediaTime,
        pixelWidth: Int,
        pixelHeight: Int,
        frameRate: FrameRate? = nil,
        addedAt: Date
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.policy = policy
        self.storagePath = storagePath
        self.duration = duration
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.frameRate = frameRate
        self.addedAt = addedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        kind = try container.decode(MediaAssetKind.self, forKey: .kind)
        policy = try container.decode(MediaReferencePolicy.self, forKey: .policy)
        storagePath = try container.decode(String.self, forKey: .storagePath)
        duration = try container.decode(MediaTime.self, forKey: .duration)
        pixelWidth = try container.decodeIfPresent(Int.self, forKey: .pixelWidth) ?? 0
        pixelHeight = try container.decodeIfPresent(Int.self, forKey: .pixelHeight) ?? 0
        frameRate = try container.decodeIfPresent(FrameRate.self, forKey: .frameRate)
        addedAt = try container.decode(Date.self, forKey: .addedAt)
    }

    /// Resolves the asset's file URL.
    ///
    /// - Parameter packageBase: the project package URL, required for
    ///   copied assets; ignored for linked assets.
    func resolvedURL(packageBase: URL?) -> URL {
        switch policy {
        case .linked:
            return URL(fileURLWithPath: storagePath)
        case .copied:
            if let packageBase {
                return packageBase.appendingPathComponent(storagePath)
            }
            return URL(fileURLWithPath: storagePath)
        }
    }

    /// True when the referenced file currently exists on disk.
    var isFilePresent: Bool {
        FileManager.default.fileExists(atPath: resolvedURL(packageBase: nil).path)
    }
}
