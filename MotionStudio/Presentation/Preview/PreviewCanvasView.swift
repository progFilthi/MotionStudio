import SwiftUI

/// Center canvas: video preview surface or an honest empty state.
struct PreviewCanvasView: View {
    @Environment(AppEnvironment.self) private var environment

    var body: some View {
        ZStack {
            WorkspaceTheme.canvasBackground
            if environment.playback.isReadyToPlay {
                AVPlayerSurface(player: environment.playback.player)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                placeholder
            }
        }
        .frame(minWidth: 480, minHeight: 260)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(WorkspaceTheme.hairline)
                .frame(height: 1)
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
                message: "Select media in the browser, or click a timeline clip, to preview it here."
            )
        }
    }
}
