import SwiftUI

/// Center canvas: video preview and, later, selection overlays.
///
/// Playback is a Milestone 1 capability and is intentionally absent.
struct PreviewCanvasView: View {
    var body: some View {
        ZStack {
            WorkspaceTheme.canvasBackground
            WorkspacePlaceholder(
                systemImage: "photo",
                title: "Preview",
                message: "The composition preview will appear here. Preview playback is not available yet."
            )
        }
        .frame(minWidth: 480, minHeight: 260)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(WorkspaceTheme.hairline)
                .frame(height: 1)
        }
    }
}
