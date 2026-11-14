import AVFoundation
import AppKit
import Observation
import SwiftUI

/// Reported when a project's linked media cannot be found on disk.
///
/// Clips are preserved (architecture §6.2: never silently delete project
/// data); the user is told which files are missing and what to do.
struct MissingMediaError: LocalizedError {
    let assetNames: [String]

    var errorDescription: String? { "Media files are missing" }

    var failureReason: String? {
        let listed = assetNames.prefix(3).joined(separator: ", ")
        let more = assetNames.count > 3 ? " and \(assetNames.count - 3) more" : ""
        return "'\(listed)\(more)' could not be found on disk. The timeline keeps every clip; move the files back or re-import them to restore playback."
    }
}

/// The application composition root for one document window.
///
/// Shared services are constructed here and injected into the
/// presentation layer through the SwiftUI environment. Dependency
/// construction must stay out of SwiftUI view bodies, and there is
/// deliberately no global service locator (architecture §4).
///
/// Document mutations flow through a project binding attached by the
/// workspace view, so edits go through the document system (dirty
/// state, autosave). Project data never depends on this session state;
/// the session state is transient (Milestone 2 acceptance criteria).
/// The typed command system of a later milestone will absorb these
/// direct edit paths.
@MainActor
@Observable
final class AppEnvironment {
    let errorReporter: AppErrorReporter
    let mediaImporter: MediaImporter
    let playback: PlaybackController

    /// The project binding attached by the workspace view. Nil until
    /// the first workspace appears.
    private var projectBinding: Binding<Project>?

    // MARK: Session state (never persisted)

    private(set) var presentedError: ErrorPresentation?

    private var selectedAssetIDStorage: UUID?
    private(set) var selectedClipID: UUID?
    private(set) var playheadTime: MediaTime = .zero
    private(set) var isImporting = false
    private(set) var missingAssetIDs: Set<UUID> = []

    /// The asset highlighted in the media browser. Setting it selects
    /// and loads the asset; nil clears the highlight only.
    var selectedAssetID: UUID? {
        get { selectedAssetIDStorage }
        set {
            guard let id = newValue else {
                selectedAssetIDStorage = nil
                return
            }
            selectAsset(byID: id)
        }
    }

    init(errorReporter: AppErrorReporter = AppErrorReporter()) {
        self.errorReporter = errorReporter
        self.mediaImporter = MediaImporter()

        let playback = PlaybackController()
        self.playback = playback

        playback.onError = { [weak self] error in
            self?.report(error, while: "playing media")
        }
        playback.onTimeChanged = { [weak self] time in
            self?.syncPlayhead(with: time)
        }

        AppLog.app.info("Application environment initialized")
    }

    /// Binding-friendly visibility of `presentedError`.
    var isPresentingError: Bool {
        get { presentedError != nil }
        set {
            guard !newValue else { return }
            presentedError = nil
        }
    }

    /// Reports a failed operation: logs technical detail and prepares a
    /// user-facing presentation.
    func report(_ error: Error, while performing: String) {
        presentedError = errorReporter.presentation(for: error, while: performing)
    }

    /// Clears the currently presented failure.
    func dismissError() {
        presentedError = nil
    }

    // MARK: Document wiring

    /// Attaches the project binding through which edits are applied.
    func attach(project: Binding<Project>) {
        projectBinding = project
    }

    private var project: Project? {
        projectBinding?.wrappedValue
    }

    private func mutate(_ transform: (inout Project) -> Void) {
        guard var project = projectBinding?.wrappedValue else { return }
        transform(&project)
        projectBinding?.wrappedValue = project
    }

    /// Prepares session state for a (possibly different) document:
    /// resets playback and selection, then audits linked media.
    func loadDocument(_ project: Project) {
        playback.unload()
        selectedAssetIDStorage = nil
        selectedClipID = nil
        playheadTime = .zero
        auditMediaAvailability(in: project)
    }

    // MARK: Media availability

    /// Checks every linked asset and reports the missing ones once.
    /// Clips are kept; missing media is never silently discarded.
    func auditMediaAvailability(in project: Project) {
        var missing = Set<UUID>()
        for asset in project.assets where !asset.isFilePresent {
            missing.insert(asset.id)
        }
        missingAssetIDs = missing

        guard !missing.isEmpty else { return }
        let names = project.assets
            .filter { missing.contains($0.id) }
            .map(\.name)
        report(MissingMediaError(assetNames: names), while: "opening the project")
    }

    // MARK: Media import

    /// Opens the import panel and inspects each selected file, adding
    /// new assets to the project through the attached binding.
    ///
    /// Cancelled panels are not errors; individual failures are reported
    /// while the remaining files continue. Files already registered
    /// (same absolute path) are selected instead of duplicated.
    func importMedia() async {
        guard !isImporting else { return }
        isImporting = true
        defer { isImporting = false }

        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = MediaFormats.allowedContentTypes
        panel.message = "Choose videos to add to the media library"
        panel.prompt = "Import"

        guard panel.runModal() == .OK, !panel.urls.isEmpty else { return }

        var firstAsset: MediaAsset?
        for url in panel.urls {
            do {
                let info = try await mediaImporter.inspect(url: url)
                let asset = Self.makeAsset(from: info, url: url)

                if let project, project.containsAsset(atPath: asset.storagePath) {
                    // Already registered: select the existing asset.
                    if firstAsset == nil,
                       let existing = project.assets.first(where: { $0.storagePath == asset.storagePath }) {
                        firstAsset = existing
                    }
                    continue
                }

                mutate { $0.addAsset(asset) }
                if firstAsset == nil {
                    firstAsset = asset
                }
            } catch {
                report(error, while: "importing '\(url.lastPathComponent)'")
            }
        }

        if let asset = firstAsset {
            select(asset: asset)
        }
    }

    /// Builds a project asset from import metadata. Linked policy for
    /// Milestone 2; copy-on-import arrives with media management.
    private static func makeAsset(from info: ImportedMediaInfo, url: URL) -> MediaAsset {
        let duration = MediaTime.fromSeconds(
            max(0, info.durationSeconds),
            timescale: Composition.timescale
        )
        return MediaAsset(
            name: url.deletingPathExtension().lastPathComponent,
            kind: info.videoTrackCount > 0 ? .video : .audio,
            policy: .linked,
            storagePath: url.standardizedFileURL.path,
            duration: duration,
            pixelWidth: Int(info.naturalSize.width),
            pixelHeight: Int(info.naturalSize.height),
            frameRate: info.frameRate.flatMap {
                FrameRateRecognition.frameRate(approximating: $0)
            },
            addedAt: Date()
        )
    }

    // MARK: Selection

    /// Selects and loads a registered asset by identifier.
    func selectAsset(byID id: UUID) {
        selectedAssetIDStorage = id
        guard let project, let asset = project.asset(withID: id) else { return }
        select(asset: asset)
    }

    /// Loads an asset into the preview, reporting a clear error when its
    /// file is missing rather than silently doing nothing.
    func select(asset: MediaAsset) {
        selectedAssetIDStorage = asset.id
        selectedClipID = nil
        missingAssetIDs.remove(asset.id)

        let url = asset.resolvedURL(packageBase: nil)
        guard asset.isFilePresent else {
            missingAssetIDs.insert(asset.id)
            report(MediaImportError.fileMissing(url), while: "opening '\(asset.name)'")
            return
        }
        playback.load(url: url)
    }

    /// Selects a timeline clip, loading its asset and placing the
    /// playhead at the clip's start.
    func selectClip(_ clip: Clip, in project: Project) {
        guard case .asset(let source) = clip.source,
              let asset = project.asset(withID: source.assetID) else {
            return
        }

        selectedClipID = clip.id
        selectedAssetIDStorage = asset.id
        playheadTime = clip.timelineStart
        missingAssetIDs.remove(asset.id)

        let url = asset.resolvedURL(packageBase: nil)
        guard asset.isFilePresent else {
            missingAssetIDs.insert(asset.id)
            report(MediaImportError.fileMissing(url), while: "opening '\(asset.name)'")
            return
        }
        playback.load(url: url, startAt: clip.sourceIn.cmTime)
    }

    /// Places the selected asset on the timeline and selects the clip.
    func addSelectedAssetToTimeline() {
        guard let project,
              let assetID = selectedAssetIDStorage,
              let asset = project.asset(withID: assetID),
              asset.isFilePresent else {
            return
        }

        var updated = project
        let clip = updated.addTimelineClip(for: asset)
        projectBinding?.wrappedValue = updated
        selectClip(clip, in: updated)
    }

    // MARK: Timeline seeking

    /// Moves the composition playhead, seeking the preview to the mapped
    /// source time when the position falls inside a clip.
    ///
    /// Clicking in an empty region pauses playback and moves the
    /// playhead only — an honest state with no content to show.
    func seekToCompositionTime(_ time: MediaTime, in project: Project) {
        var targetClip: Clip?

        if let (_, selected) = project.clip(withID: selectedClipID) {
            let range = selected.timelineRange
            if time >= range.start, time < range.end {
                targetClip = selected
            }
        }
        if targetClip == nil, let found = TimelineMapper.clip(at: time, in: project.composition) {
            targetClip = found.clip
        }

        if let clip = targetClip {
            if clip.id == selectedClipID {
                playheadTime = time
                let source = TimelineMapper.sourceTime(forCompositionTime: time, in: clip)
                playback.seek(to: source.cmTime)
            } else {
                selectClip(clip, in: project)
                playheadTime = time
            }
        } else {
            playback.pause()
            playheadTime = time
        }
    }

    // MARK: Playhead sync

    /// Maps playback time into composition time while a clip is loaded.
    private func syncPlayhead(with time: CMTime) {
        guard let project,
              let (_, clip) = project.clip(withID: selectedClipID) else {
            return
        }
        let source = MediaTime(cmTime: time)
        playheadTime = TimelineMapper.compositionTime(forSourceTime: source, in: clip)
    }
}
