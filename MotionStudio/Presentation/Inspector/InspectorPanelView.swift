import SwiftUI

/// Right region: context-sensitive properties now, AI assistant later.
///
/// Selection and inspection arrive with layer support; the assistant is a
/// later milestone entirely.
struct InspectorPanelView: View {
    var body: some View {
        VStack(spacing: 0) {
            WorkspacePanelHeader(title: "Inspector")
            WorkspacePlaceholder(
                systemImage: "slider.horizontal.3",
                title: "Inspector",
                message: "Properties for the selected layer will appear here. Selection and inspection are not available yet."
            )
        }
        .frame(minWidth: 260, maxWidth: 400)
        .background(WorkspaceTheme.panelBackground)
    }
}
