import SwiftUI

/// The bottom timeline panel: ruler, playhead, track rows, and clip
/// blocks (roadmap Milestone 2).
///
/// The playhead reflects composition time; dragging or clicking the
/// ruler seeks the preview to the mapped source time. Track order
/// follows the domain convention: index 0 is the topmost row. Zoom is
/// session state and is not persisted.
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
                zoomControls
            }

            timelineContent
        }
        .frame(minHeight: 200)
        .background(WorkspaceTheme.panelBackground)
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
                .overlay(alignment: .leading) {
                    playhead
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    // MARK: Ruler

    /// Labeled tick interval chosen so labels stay ~90 pt apart.
    private var tickInterval: Double {
        let candidates: [Double] = [0.1, 0.25, 0.5, 1, 2, 5, 10, 15, 30, 60]
        return candidates.first { $0 * pixelsPerSecond >= 90 } ?? 60
    }

    private var ruler: some View {
        Canvas { context, size in
            let interval = tickInterval
            var tick = 0.0
            while tick <= visibleLength {
                let x = tick * pixelsPerSecond
                if x <= size.width {
                    let label = PlaybackTimeFormatting.shortFormat(seconds: tick)
                    context.draw(
                        Text(label)
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundStyle(WorkspaceTheme.textTertiary),
                        at: CGPoint(x: x + 3, y: size.height * 0.32),
                        anchor: .leading
                    )
                    context.stroke(
                        Path(CGRect(x: x, y: size.height * 0.55, width: 1, height: size.height * 0.45)),
                        with: .color(WorkspaceTheme.hairline),
                        lineWidth: 1
                    )
                }
                tick += interval
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
    }

    private func trackLane(_ track: Track) -> some View {
        ZStack(alignment: .leading) {
            WorkspaceTheme.panelBackground
            ForEach(track.clips) { clip in
                ClipBlockView(
                    clip: clip,
                    isSelected: clip.id == environment.selectedClipID,
                    isDimmed: !track.isVisible
                )
                .frame(width: max(clip.timelineDuration.seconds * pixelsPerSecond, 24))
                .offset(x: clip.timelineStart.seconds * pixelsPerSecond)
                .onTapGesture {
                    guard !track.isLocked else { return }
                    environment.selectClip(clip, in: project)
                }
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
private struct ClipBlockView: View {
    let clip: Clip
    let isSelected: Bool
    let isDimmed: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(clip.name)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(WorkspaceTheme.textPrimary)
                .lineLimit(1)
            Text(PlaybackTimeFormatting.shortFormat(seconds: clip.timelineDuration.seconds))
                .font(.system(size: 8, design: .monospaced))
                .foregroundStyle(WorkspaceTheme.textTertiary)
                .lineLimit(1)
        }
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(WorkspaceTheme.accent.opacity(isSelected ? 0.45 : 0.25))
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
        .help("\(clip.name) — click to select")
    }
}
