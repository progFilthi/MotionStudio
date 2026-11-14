import SwiftUI

/// The main editing workspace.
///
/// Regions (architecture §12): toolbar, left media sidebar, center preview,
/// bottom timeline, right inspector. Panels resize through the split views
/// and collapse through toolbar toggles; choices persist across launches.
struct WorkspaceView: View {
    @Environment(AppEnvironment.self) private var environment

    @State private var layout = WorkspaceLayoutState()

    var body: some View {
        @Bindable var bindableEnvironment = environment

        VStack(spacing: 0) {
            WorkspaceToolbar(layout: layout)

            HSplitView {
                if layout.isMediaBrowserVisible {
                    MediaSidebarView()
                }

                VSplitView {
                    PreviewCanvasView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    if layout.isTimelineVisible {
                        TimelinePanelView()
                    }
                }
                .frame(minWidth: 560)

                if layout.isInspectorVisible {
                    InspectorPanelView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 1180, minHeight: 760)
        .background(WorkspaceTheme.windowBackground)
        .alert(
            bindableEnvironment.presentedError?.title ?? "Something went wrong",
            isPresented: $bindableEnvironment.isPresentingError,
            presenting: bindableEnvironment.presentedError
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { presentation in
            Text(presentation.message)
        }
    }
}
