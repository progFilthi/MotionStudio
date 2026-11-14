import Foundation

/// The project document: identity, composition, and registered assets
/// (architecture §5.1).
///
/// One composition per project for now; the model keeps the door open
/// for more later without changing the persisted shape.
nonisolated struct Project: Codable, Hashable, Sendable {
    /// The project format version this model represents. The manifest
    /// envelope (`ProjectManifest`) carries the authoritative schema
    /// version; this field must agree with it on load.
    var schemaVersion: Int

    let id: UUID
    var name: String
    var createdAt: Date
    var updatedAt: Date
    var composition: Composition
    var assets: [MediaAsset]

    init(
        schemaVersion: Int,
        id: UUID = UUID(),
        name: String,
        createdAt: Date,
        updatedAt: Date,
        composition: Composition,
        assets: [MediaAsset] = []
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.composition = composition
        self.assets = assets
    }

    /// A fresh untitled project: one video track, 1080p at 30 fps,
    /// ten-second composition duration.
    ///
    /// - Parameter schemaVersion: the project format version to stamp.
    ///   The document layer passes the current format version (the
    ///   Domain layer must not depend on persistence).
    static func empty(schemaVersion: Int) -> Project {
        let composition = Composition(
            name: "Main Composition",
            width: 1920,
            height: 1080,
            frameRate: .fps30,
            duration: .exact(6000, over: Composition.timescale),
            background: .black,
            tracks: [Track(name: "Video 1", kind: .video)]
        )
        let now = Date()
        return Project(
            schemaVersion: schemaVersion,
            name: "Untitled Project",
            createdAt: now,
            updatedAt: now,
            composition: composition
        )
    }

    /// The asset with a given identifier, if registered.
    func asset(withID id: UUID?) -> MediaAsset? {
        guard let id else { return nil }
        return assets.first { $0.id == id }
    }

    /// True when an asset referencing the same absolute path already
    /// exists. Prevents duplicate registrations of one file.
    func containsAsset(atPath path: String) -> Bool {
        assets.contains { asset in
            asset.policy == .linked && asset.storagePath == path
        }
    }

    /// Registers an asset. Callers decide uniqueness (see
    /// `containsAsset(atPath:)`).
    mutating func addAsset(_ asset: MediaAsset) {
        assets.append(asset)
    }

    /// Places an imported asset on the timeline as a new clip.
    ///
    /// The clip starts after the last clip on the asset's kind track
    /// (creating the track if needed) and plays the full source range.
    /// The composition duration grows when the clip extends past it.
    /// Clips on a track stay sorted by start and never overlap.
    ///
    /// - Returns: the created clip.
    @discardableResult
    mutating func addTimelineClip(for asset: MediaAsset) -> Clip {
        let trackKind: TrackKind = asset.kind == .video ? .video : .audio
        let trackName = asset.kind == .video ? "Video \(videoTrackCount + 1)" : "Audio \(audioTrackCount + 1)"
        let track = composition.track(forKind: trackKind, named: trackName)

        let start = track.endOfLastClip
        let clip = Clip(
            name: asset.name,
            source: .asset(MediaAssetSource(assetID: asset.id)),
            timelineStart: start,
            timelineDuration: asset.duration,
            sourceIn: .zero,
            sourceOut: asset.duration
        )

        let trackIndex = composition.tracks.firstIndex { $0.id == track.id } ?? 0
        composition.tracks[trackIndex].clips.append(clip)

        let clipEnd = start + asset.duration
        if clipEnd > composition.duration {
            composition.duration = clipEnd
        }
        return clip
    }

    /// The last clip placed for an asset, used to select it after
    /// placement.
    func lastTimelineClip(forAssetID assetID: UUID) -> Clip? {
        for track in composition.tracks {
            if let clip = track.clips.last(where: { clip in
                if case .asset(let source) = clip.source {
                    return source.assetID == assetID
                }
                return false
            }) {
                return clip
            }
        }
        return nil
    }

    /// The clip with a given identifier anywhere in the timeline.
    func clip(withID id: UUID?) -> (track: Track, clip: Clip)? {
        guard let id else { return nil }
        for track in composition.tracks {
            if let clip = track.clips.first(where: { $0.id == id }) {
                return (track, clip)
            }
        }
        return nil
    }

    private var videoTrackCount: Int {
        composition.tracks.filter { $0.kind == .video }.count
    }

    private var audioTrackCount: Int {
        composition.tracks.filter { $0.kind == .audio }.count
    }
}
