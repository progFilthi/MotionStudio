import SwiftUI

/// The bottom timeline panel: ruler, playhead, track rows, and clip
/// blocks (roadmap Milestone 2).
///
/// The playhead reflects composition time; dragging the ruler scrubs
/// and clicking anywhere on the timeline moves the playhead to the
/// clicked time. Track order follows the domain convention: index 0 is
/// the topmost row. Zoom is session state and is not persisted.
struct TimelinePanelView: View {
    @Binding var project: Project
    @Environment(AppEnvironment.self) private var environment

    @State private var pixelsPerSecond: Double = 120
    @State private var isScrubbing = false
    @State private var wasPlayingBeforeScrub = false

    private let rulerHeight: CGFloat = 26
    private let laneHeight: CGFloat = 44

    var body: some View {
        VStack(spacing: 0) {
            WorkspacePanelHeader(title: "Timeline") {
                HStack(spacing: 10) {
                    addTextButton
                    zoomControls
                }
            }

            timelineContent
        }
        .frame(minHeight: 200)
        .background(WorkspaceTheme.panelBackground)
    }

    /// Places a typed text clip at the playhead (roadmap Milestone 3).
    private var addTextButton: some View {
        Button {
            environment.addTextClip()
        } label: {
            Label("Text", systemImage: "textformat")
                .font(.system(size: 11, weight: .medium))
        }
        .buttonStyle(.plain)
        .foregroundStyle(WorkspaceTheme.textSecondary)
        .help("Add a text layer at the playhead (⌘T)")
    }

    // MARK: Layout

    /// Composition length that must be visible: composition duration,
    /// the furthest clip, and one second of breathing room.
    private var visibleLength: Double {
        let furthestClipEnd = project.composition.tracks
            .map { $0.endOfLastClip.seconds }
            .max() ?? 0
        return max(project.composition.duration.seconds, furthestClipEnd) + 1
    }

    private var contentWidth: CGFloat {
        max(visibleLength * pixelsPerSecond, 0)
    }

    @ViewBuilder
    private var timelineContent: some View {
        GeometryReader { geometry in
            ScrollView(.horizontal) {
                VStack(spacing: 0) {
                    ruler
                    trackLanes
                }
                .frame(
                    width: max(contentWidth, geometry.size.width),
                    alignment: .leading
                )
                .coordinateSpace(name: "timelineContent")
                .overlay(alignment: .leading) {
                    playhead
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    // MARK: Ruler

    private var ruler: some View {
        Canvas { context, size in
            let interval = TimelineRulerMetrics.labeledInterval(pixelsPerSecond: pixelsPerSecond)
            let minor = TimelineRulerMetrics.minorInterval(
                labeled: interval,
                pixelsPerSecond: pixelsPerSecond
            )

            // Unlabeled minor ticks between the labeled ones; every
            // fifth minor coincides with a labeled tick and is skipped.
            if let minor {
                let minorCount = Int((visibleLength / minor).rounded(.up))
                for index in 0...max(minorCount, 0) where index % 5 != 0 {
                    let x = Double(index) * minor * pixelsPerSecond
                    if x <= size.width {
                        context.stroke(
                            Path(CGRect(
                                x: x,
                                y: size.height * 0.75,
                                width: 1,
                                height: size.height * 0.25
                            )),
                            with: .color(WorkspaceTheme.hairline.opacity(0.6)),
                            lineWidth: 1
                        )
                    }
                }
            }

            // Labeled ticks. Index-based so tick positions never drift
            // through repeated floating-point addition on long videos.
            let tickCount = Int((visibleLength / interval).rounded(.up))
            for index in 0...max(tickCount, 0) {
                let tick = Double(index) * interval
                let x = tick * pixelsPerSecond
                if x <= size.width {
                    let labelColor = TimelineRulerMetrics.isMinuteMark(
                        seconds: tick,
                        interval: interval
                    ) ? WorkspaceTheme.textSecondary : WorkspaceTheme.textTertiary
                    context.draw(
                        Text(TimelineRulerMetrics.label(seconds: tick, interval: interval))
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundStyle(labelColor),
                        at: CGPoint(x: x + 3, y: size.height * 0.32),
                        anchor: .leading
                    )
                    context.stroke(
                        Path(CGRect(x: x, y: size.height * 0.55, width: 1, height: size.height * 0.45)),
                        with: .color(WorkspaceTheme.hairline),
                        lineWidth: 1
                    )
                }
            }
        }
        .frame(height: rulerHeight)
        .background(WorkspaceTheme.toolbarBackground)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(WorkspaceTheme.hairline)
                .frame(height: 1)
        }
        .contentShape(Rectangle())
        .gesture(scrubGesture)
        .help("Drag to scrub the preview")
    }

    // MARK: Tracks and clips

    private var trackLanes: some View {
        VStack(spacing: 0) {
            ForEach(project.composition.tracks) { track in
                trackLane(track)
            }
            Spacer(minLength: 0)
        }
        .frame(minHeight: 120)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(WorkspaceTheme.hairline)
                .frame(height: 1)
        }
        .contentShape(Rectangle())
        .onTapGesture(coordinateSpace: .named("timelineContent")) { location in
            seekToContent(x: location.x)
        }
        .help("Click to move the playhead; click a clip to select it")
    }

    /// Moves the playhead to the composition time under the given
    /// content-space x position. `seekToCompositionTime` selects a
    /// playable clip under the position as part of the seek.
    private func seekToContent(x: CGFloat) {
        let seconds = max(0, x / pixelsPerSecond)
        environment.seekToCompositionTime(
            .fromSeconds(seconds, timescale: Composition.timescale),
            in: project
        )
    }

    private func trackLane(_ track: Track) -> some View {
        ZStack(alignment: .leading) {
            WorkspaceTheme.panelBackground
            ForEach(track.clips) { clip in
                ClipBlockView(
                    clip: clip,
                    isSelected: clip.id == environment.selectedClipID,
                    isDimmed: !track.isVisible,
                    playheadTime: environment.playheadTime,
                    frameTolerance: project.composition.frameRate.halfFrameDuration,
                    pixelsPerSecond: pixelsPerSecond
                )
                .frame(width: max(clip.timelineDuration.seconds * pixelsPerSecond, 24))
                .offset(x: clip.timelineStart.seconds * pixelsPerSecond)
            }
            if track.isLocked {
                Image(systemName: "lock.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(WorkspaceTheme.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, 6)
            }
        }
        .frame(height: laneHeight)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(WorkspaceTheme.hairline)
                .frame(height: 1)
        }
        .opacity(track.isLocked ? 0.75 : 1)
    }

    // MARK: Playhead

    private var playhead: some View {
        Rectangle()
            .fill(WorkspaceTheme.accent)
            .frame(width: 1)
            .overlay(alignment: .top) {
                TriangleHead()
                    .fill(WorkspaceTheme.accent)
                    .frame(width: 9, height: 7)
                    .offset(x: 0, y: 2)
            }
            .offset(x: environment.playheadTime.seconds * pixelsPerSecond)
            .allowsHitTesting(false)
    }

    // MARK: Gestures and controls

    private var scrubGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if !isScrubbing {
                    isScrubbing = true
                    wasPlayingBeforeScrub = environment.playback.isPlaying
                    environment.playback.pause()
                }
                let seconds = value.location.x / pixelsPerSecond
                environment.seekToCompositionTime(
                    .fromSeconds(seconds, timescale: Composition.timescale),
                    in: project
                )
            }
            .onEnded { _ in
                isScrubbing = false
                if wasPlayingBeforeScrub {
                    environment.playback.play()
                }
            }
    }

    private var zoomControls: some View {
        HStack(spacing: 10) {
            Button {
                pixelsPerSecond = max(20, pixelsPerSecond / 1.25)
            } label: {
                Image(systemName: "minus.magnifyingglass")
            }
            .buttonStyle(.plain)
            .foregroundStyle(WorkspaceTheme.textSecondary)
            .help("Zoom out")

            Button {
                pixelsPerSecond = min(600, pixelsPerSecond * 1.25)
            } label: {
                Image(systemName: "plus.magnifyingglass")
            }
            .buttonStyle(.plain)
            .foregroundStyle(WorkspaceTheme.textSecondary)
            .help("Zoom in")
        }
    }
}

/// Small triangle marking the playhead position on the ruler.
private nonisolated struct TriangleHead: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

/// One clip block on a track lane.
///
/// Shows the clip name and duration; keyframed clips draw one diamond
/// per distinct keyframe time along the bottom edge (roadmap Milestone
/// 3). The diamond under the playhead highlights so scrubbing makes
/// keyframe hits visible.
private struct ClipBlockView: View {
    let clip: Clip
    let isSelected: Bool
    let isDimmed: Bool
    let playheadTime: MediaTime
    let frameTolerance: MediaTime
    let pixelsPerSecond: Double

    private let isTextLayer: Bool

    init(
        clip: Clip,
        isSelected: Bool,
        isDimmed: Bool,
        playheadTime: MediaTime,
        frameTolerance: MediaTime,
        pixelsPerSecond: Double
    ) {
        self.clip = clip
        self.isSelected = isSelected
        self.isDimmed = isDimmed
        self.playheadTime = playheadTime
        self.frameTolerance = frameTolerance
        self.pixelsPerSecond = pixelsPerSecond
        self.isTextLayer = clip.isText
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 3) {
                if isTextLayer {
                    Image(systemName: "textformat")
                        .font(.system(size: 8))
                        .foregroundStyle(WorkspaceTheme.textPrimary)
                }
                Text(clip.name)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(WorkspaceTheme.textPrimary)
                    .lineLimit(1)
            }
            Text(PlaybackTimeFormatting.shortFormat(seconds: clip.timelineDuration.seconds))
                .font(.system(size: 8, design: .monospaced))
                .foregroundStyle(WorkspaceTheme.textTertiary)
                .lineLimit(1)
        }
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(blockFill)
        .overlay(keyframeDiamonds)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(
                    isSelected ? WorkspaceTheme.accent : WorkspaceTheme.hairline,
                    lineWidth: isSelected ? 2 : 1
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .opacity(isDimmed ? 0.4 : 1)
        .contentShape(Rectangle())
        .help(helpText)
    }

    private var blockFill: Color {
        if isTextLayer {
            return WorkspaceTheme.textSecondary.opacity(isSelected ? 0.4 : 0.22)
        }
        return WorkspaceTheme.accent.opacity(isSelected ? 0.45 : 0.25)
    }

    private var helpText: String {
        if isTextLayer {
            return "\(clip.name) — text layer, click to select"
        }
        return "\(clip.name) — click to select"
    }

    // MARK: Keyframe diamonds

    /// Distinct keyframe times across all animations of the clip,
    /// sorted by clip-local time.
    private var keyframeTimes: [MediaTime] {
        var seen = Set<MediaTime>()
        var times: [MediaTime] = []
        for animation in clip.animations {
            for keyframe in animation.keyframes where !seen.contains(keyframe.time) {
                seen.insert(keyframe.time)
                times.append(keyframe.time)
            }
        }
        return times.sorted()
    }

    /// The keyframe (if any) falling under the playhead within the
    /// half-frame tolerance, across all animations.
    private var keyframeAtPlayhead: Keyframe? {
        let localTime = playheadTime - clip.timelineStart
        return clip.animations.lazy
            .compactMap { $0.keyframe(near: localTime, tolerance: frameTolerance) }
            .first
    }

    @ViewBuilder
    private var keyframeDiamonds: some View {
        let marked = keyframeAtPlayhead?.time
        GeometryReader { geometry in
            ForEach(Array(keyframeTimes.enumerated()), id: \.offset) { _, time in
                KeyframeDiamond(isAtPlayhead: time == marked)
                    .fill(time == marked ? WorkspaceTheme.accent : WorkspaceTheme.textPrimary.opacity(0.9))
                    .frame(width: 7, height: 7)
                    .position(
                        x: time.seconds * pixelsPerSecond,
                        y: geometry.size.height - 6
                    )
            }
        }
        .allowsHitTesting(false)
    }
}

/// Small diamond marking a keyframe position on a clip block.
private nonisolated struct KeyframeDiamond: Shape {
    let isAtPlayhead: Bool

    func path(in rect: CGRect) -> Path {
        let size = isAtPlayhead ? 4.2 : 3.4
        let center = CGPoint(x: rect.midX, y: rect.midY)
        var path = Path()
        path.move(to: CGPoint(x: center.x, y: center.y - size))
        path.addLine(to: CGPoint(x: center.x + size, y: center.y))
        path.addLine(to: CGPoint(x: center.x, y: center.y + size))
        path.addLine(to: CGPoint(x: center.x - size, y: center.y))
        path.closeSubpath()
        return path
    }
}
