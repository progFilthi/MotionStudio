import SwiftUI

/// Center canvas: video preview surface with text overlays, or an
/// honest empty state.
///
/// Text layers active at the playhead render as SwiftUI overlays on top
/// of the video (roadmap Milestone 3). This is a presentation-layer
/// approximation — the compositing render engine of a later milestone
/// replaces it with canvas-true drawing at composition resolution.
///
/// Overlay geometry maps composition coordinates onto the aspect-fit
/// rect of the **composition canvas**. When the loaded video's aspect
/// matches the composition's (the common case), overlays sit exactly
/// over the video content; differing aspects letterbox the video and
/// the overlay rect diverges — a documented preview limitation.
struct PreviewCanvasView: View {
    let project: Project

    @Environment(AppEnvironment.self) private var environment

    var body: some View {
        GeometryReader { geometry in
            let contentRect = Self.contentRect(
                for: geometry.size,
                compositionSize: CGSize(
                    width: CGFloat(project.composition.width),
                    height: CGFloat(project.composition.height)
                )
            )
            ZStack {
                WorkspaceTheme.canvasBackground
                if environment.playback.isReadyToPlay {
                    AVPlayerSurface(player: environment.playback.player)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if overlays.isEmpty {
                    placeholder
                }
                ForEach(overlays) { overlay in
                    TextOverlayView(
                        overlay: overlay,
                        contentRect: contentRect,
                        compositionSize: CGSize(
                            width: CGFloat(project.composition.width),
                            height: CGFloat(project.composition.height)
                        )
                    )
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .frame(minWidth: 480, minHeight: 260)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(WorkspaceTheme.hairline)
                .frame(height: 1)
        }
    }

    /// Text overlays active at the playhead, evaluated by the
    /// environment (reads playheadTime, so playback updates them live).
    private var overlays: [TextOverlay] {
        environment.activeTextOverlays(in: project)
    }

    /// Aspect-fit rect of the composition canvas inside the view.
    ///
    /// Static and pure so previews and tests can verify the mapping.
    static func contentRect(for size: CGSize, compositionSize: CGSize) -> CGRect {
        guard size.width > 0, size.height > 0,
              compositionSize.width > 0, compositionSize.height > 0 else {
            return CGRect(origin: .zero, size: size)
        }
        let contentAspect = compositionSize.width / compositionSize.height
        let viewAspect = size.width / size.height
        if contentAspect > viewAspect {
            let height = size.width / contentAspect
            return CGRect(x: 0, y: (size.height - height) / 2, width: size.width, height: height)
        } else {
            let width = size.height * contentAspect
            return CGRect(x: (size.width - width) / 2, y: 0, width: width, height: size.height)
        }
    }

    @ViewBuilder
    private var placeholder: some View {
        if environment.playback.hasPlaybackFailure {
            WorkspacePlaceholder(
                systemImage: "exclamationmark.triangle",
                title: "Playback Failed",
                message: "The media could not be played. The file may be missing, damaged, or in an unsupported codec."
            )
        } else if environment.playback.hasItem {
            WorkspacePlaceholder(
                systemImage: "photo",
                title: "Loading Preview",
                message: "Preparing the media for playback."
            )
        } else {
            WorkspacePlaceholder(
                systemImage: "photo",
                title: "Preview",
                message: "Select media in the browser, or click a timeline clip, to preview it here. Add text with the Text button in the timeline."
            )
        }
    }
}
