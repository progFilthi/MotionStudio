import SwiftUI

/// Left sidebar: media browser and, later, animation presets.
///
/// Media import is a Milestone 1 capability and is intentionally absent.
struct MediaSidebarView: View {
    var body: some View {
        VStack(spacing: 0) {
            WorkspacePanelHeader(title: "Media")
            WorkspacePlaceholder(
                systemImage: "square.grid.2x2",
                title: "Media Browser",
                message: "Imported footage and graphics will appear here. Media import is not available yet."
            )
        }
        .frame(minWidth: 220, maxWidth: 380)
        .background(WorkspaceTheme.panelBackground)
    }
}
