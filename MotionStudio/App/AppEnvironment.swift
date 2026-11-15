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

/// A text clip active at the playhead with its evaluated animation
/// values — the presentation input for preview overlays. Session-layer
/// type: never persisted.
nonisolated struct TextOverlay: Identifiable, Hashable, Sendable {
    let clip: Clip
    let values: ResolvedClipValues

    var id: UUID { clip.id }
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
        var placedClip: Clip?
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

                // An empty timeline adopts the first imported asset, so
                // a fresh project immediately spans the imported media
                // instead of its default ten seconds. Later imports stay
                // in the library until they are placed explicitly.
                if placedClip == nil,
                   let current = project,
                   current.composition.tracks.allSatisfy({ $0.clips.isEmpty }) {
                    var updated = current
                    placedClip = updated.addTimelineClip(for: asset)
                    projectBinding?.wrappedValue = updated
                }

                if firstAsset == nil {
                    firstAsset = asset
                }
            } catch {
                report(error, while: "importing '\(url.lastPathComponent)'")
            }
        }

        if let clip = placedClip, let project {
            selectClip(clip, in: project)
        } else if let asset = firstAsset {
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
    ///
    /// Text layers have no media to load: selecting one pauses playback
    /// (a stable editing state), keeps the already-loaded video, and
    /// moves the playhead to the clip's start.
    func selectClip(_ clip: Clip, in project: Project) {
        guard case .asset(let source) = clip.source else {
            playback.pause()
            selectedClipID = clip.id
            playheadTime = clip.timelineStart
            return
        }
        guard let asset = project.asset(withID: source.assetID) else {
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
    /// source time when the position falls inside a playable clip.
    ///
    /// While the selected clip contains the position, selection stays
    /// stable while scrubbing — text layers included, so a selected text
    /// clip is not swapped out mid-edit. Seeking into a text-only region
    /// pauses playback and moves the playhead only: an honest state with
    /// no media to drive. Regions where a text layer overlaps video
    /// still drive the video underneath.
    func seekToCompositionTime(_ time: MediaTime, in project: Project) {
        if let (_, selected) = project.clip(withID: selectedClipID) {
            let range = selected.timelineRange
            if time >= range.start, time < range.end {
                if selected.isPlayable {
                    playheadTime = time
                    let source = TimelineMapper.sourceTime(forCompositionTime: time, in: selected)
                    playback.seek(to: source.cmTime)
                } else {
                    playback.pause()
                    playheadTime = time
                }
                return
            }
        }

        if let found = TimelineMapper.clip(at: time, in: project.composition), found.clip.isPlayable {
            selectClip(found.clip, in: project)
            playheadTime = time
            // `selectClip` positions playback at the clip's start; this
            // seek moves it to the clicked position, so the preview is
            // paused exactly where the playhead stands and pressing
            // play resumes from the playhead.
            let source = TimelineMapper.sourceTime(forCompositionTime: time, in: found.clip)
            playback.seek(to: source.cmTime)
        } else {
            playback.pause()
            playheadTime = time
        }
    }

    // MARK: Playhead sync

    /// Maps playback time into composition time while a clip is loaded.
    ///
    /// Only playable (asset) clips are synced: text selection pauses
    /// playback and never drives the playhead from a media clock.
    private func syncPlayhead(with time: CMTime) {
        guard let project,
              let (_, clip) = project.clip(withID: selectedClipID),
              clip.isPlayable else {
            return
        }
        let source = MediaTime(cmTime: time)
        playheadTime = TimelineMapper.compositionTime(forSourceTime: source, in: clip)
    }

    // MARK: Text layers

    /// Adds a typed text clip at the playhead and selects it. The clip
    /// lives on the dedicated text track; the composition duration
    /// grows when the clip extends past it.
    func addTextClip() {
        guard let project else { return }
        var updated = project
        let clip = updated.addTextClip(at: playheadTime)
        projectBinding?.wrappedValue = updated
        selectClip(clip, in: updated)
    }

    /// Removes the selected clip from the timeline. Tracks are
    /// structural and stay; the already-loaded video is not unloaded.
    func deleteSelectedClip() {
        guard let project, let id = selectedClipID else { return }
        var updated = project
        guard updated.removeClip(withID: id) != nil else { return }
        selectedClipID = nil
        projectBinding?.wrappedValue = updated
    }

    /// Applies an edit to the selected text clip, validating the result.
    ///
    /// The edit runs on a copy of the project and only publishes when
    /// the edited clip validates, so invalid edits never apply
    /// partially.
    func updateSelectedTextClip(_ perform: (inout Clip) -> Void) {
        guard let project, let id = selectedClipID else { return }
        var updated = project
        guard let clip = updated.updateClip(withID: id, perform: perform), clip.isText else { return }
        do {
            try clip.validate()
        } catch {
            report(error, while: "editing the text clip")
            return
        }
        projectBinding?.wrappedValue = updated
    }

    // MARK: Animation editing

    /// Toggles a keyframe for a property on the selected clip at the
    /// playhead.
    ///
    /// A new keyframe captures the property's current evaluated value at
    /// the playhead, so adding keys never causes the value to jump. When
    /// the playhead is outside the clip's range, the keyframe clamps to
    /// the nearest end of the clip so the action always has a visible
    /// effect. Removing the last keyframe removes the animation with it.
    func toggleKeyframe(for property: AnimatableProperty) {
        guard let project, let id = selectedClipID, let (_, clip) = project.clip(withID: id) else { return }
        let localTime = (playheadTime - clip.timelineStart).clamped(to: .zero...clip.timelineDuration)
        let tolerance = project.composition.frameRate.halfFrameDuration

        var updated = project
        var failure: Error?
        updated.updateClip(withID: id) { target in
            let value = currentValue(of: property, in: clip)
            if let existing = clip.animation(for: property)?.keyframe(near: localTime, tolerance: tolerance) {
                target.updateAnimation(for: property) { $0.removeKeyframe(at: existing.time) }
                dropAnimationIfEmpty(&target, property: property)
                return
            }
            if clip.animation(for: property) != nil {
                target.updateAnimation(for: property) { animation in
                    do {
                        try animation.insert(Keyframe(time: localTime, value: value))
                    } catch {
                        failure = error
                    }
                }
                return
            }
            target.animations.append(Animation(
                property: property,
                keyframes: [Keyframe(time: localTime, value: value)]
            ))
        }
        if let failure {
            report(failure, while: "editing keyframes")
            return
        }
        projectBinding?.wrappedValue = updated
    }

    /// Removes the keyframe for a property at a clip-local composition
    /// time, when one exists. Removing the last keyframe removes the
    /// animation with it.
    func removeKeyframe(for property: AnimatableProperty, at localTime: MediaTime) {
        updateSelectedTextClip { clip in
            clip.updateAnimation(for: property) { $0.removeKeyframe(at: localTime) }
            dropAnimationIfEmpty(&clip, property: property)
        }
    }

    /// Updates the value and/or interpolation of the keyframe for a
    /// property at a clip-local composition time. The edit validates
    /// like every other text-clip edit.
    func updateKeyframe(
        for property: AnimatableProperty,
        at localTime: MediaTime,
        value: Double? = nil,
        interpolation: Interpolation? = nil
    ) {
        updateSelectedTextClip { clip in
            clip.updateAnimation(for: property) { animation in
                guard let index = animation.keyframes.firstIndex(where: { $0.time == localTime }) else {
                    return
                }
                if let value {
                    animation.keyframes[index].value = value
                }
                if let interpolation {
                    animation.keyframes[index].interpolation = interpolation
                }
            }
        }
    }

    /// Adds an animation for a property, seeded with a single keyframe
    /// at the playhead holding the property's current value. Does
    /// nothing when the property is already animated.
    func addAnimation(for property: AnimatableProperty) {
        guard let project, let id = selectedClipID, let (_, clip) = project.clip(withID: id),
              clip.animation(for: property) == nil else {
            return
        }
        let localTime = (playheadTime - clip.timelineStart).clamped(to: .zero...clip.timelineDuration)
        let value = currentValue(of: property, in: clip)
        updateSelectedTextClip { target in
            target.animations.append(Animation(
                property: property,
                keyframes: [Keyframe(time: localTime, value: value)]
            ))
        }
    }

    /// Removes the whole animation for a property.
    func removeAnimation(for property: AnimatableProperty) {
        updateSelectedTextClip { clip in
            clip.animations.removeAll { $0.property == property }
        }
    }

    /// Adds the animation for a property when absent, removes it when
    /// present.
    func toggleAnimation(for property: AnimatableProperty) {
        guard let project, let id = selectedClipID, let (_, clip) = project.clip(withID: id) else { return }
        if clip.animation(for: property) != nil {
            removeAnimation(for: property)
        } else {
            addAnimation(for: property)
        }
    }

    /// The property's value at the playhead: the evaluated animation
    /// value when animated, the static clip value otherwise.
    private func currentValue(of property: AnimatableProperty, in clip: Clip) -> Double {
        let localTime = playheadTime - clip.timelineStart
        if let animation = clip.animation(for: property),
           let value = AnimationEvaluator.value(of: animation, atClipLocalTime: localTime) {
            return value
        }
        return property.staticValue(of: clip)
    }

    /// An animation without keyframes carries no information; remove it
    /// so the clip never keeps a phantom animation entry.
    private func dropAnimationIfEmpty(_ clip: inout Clip, property: AnimatableProperty) {
        if clip.animation(for: property)?.keyframes.isEmpty == true {
            clip.animations.removeAll { $0.property == property }
        }
    }

    // MARK: Preview overlays

    /// The text overlays active at the playhead, with their evaluated
    /// scale and opacity. Ordering follows track order (topmost first).
    func activeTextOverlays(in project: Project) -> [TextOverlay] {
        var overlays: [TextOverlay] = []
        for track in project.composition.tracks {
            for clip in track.clips where clip.isText {
                let range = clip.timelineRange
                guard playheadTime >= range.start, playheadTime < range.end else { continue }
                overlays.append(TextOverlay(
                    clip: clip,
                    values: AnimationEvaluator.resolvedValues(for: clip, atCompositionTime: playheadTime)
                ))
            }
        }
        return overlays
    }
}
