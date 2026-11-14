import SwiftUI

/// Bottom region: ruler, tracks, clips, playhead, and keyframes.
///
/// Timeline editing is a Milestone 2 capability and is intentionally absent.
struct TimelinePanelView: View {
    var body: some View {
        VStack(spacing: 0) {
            WorkspacePanelHeader(title: "Timeline")
            WorkspacePlaceholder(
                systemImage: "list.bullet.rectangle",
                title: "No Tracks Yet",
                message: "Tracks, clips, and the playhead will appear here once the timeline is implemented."
            )
        }
        .frame(minHeight: 170)
        .background(WorkspaceTheme.panelBackground)
    }
}
