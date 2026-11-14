import AppKit
import SwiftUI

/// The main editing workspace.
///
/// Regions (architecture §12): toolbar, left media sidebar, center
/// preview, bottom timeline, right inspector. Panels resize through the
/// split views and collapse through toolbar toggles; choices persist
/// across launches. The space key toggles play/pause via a guarded
/// local event monitor.
///
/// The project arrives as a binding from the document system: edits
/// applied through it mark the document dirty and autosave. Session
/// state (selection, playhead) lives in the environment and is never
/// part of project data.
struct WorkspaceView: View {
    @Binding var project: Project
    /// The window's environment: created here and provided to the
    /// workspace content below. Child views read it through
    /// `@Environment(AppEnvironment.self)`; scene commands resolve it
    /// through `focusedSceneValue`.
    @State private var environment = AppEnvironment()

    @State private var layout = WorkspaceLayoutState()
    @State private var keyMonitor: Any?

    var body: some View {
        @Bindable var bindableEnvironment = environment

        VStack(spacing: 0) {
            WorkspaceToolbar(layout: layout, projectName: project.name)

            HSplitView {
                if layout.isMediaBrowserVisible {
                    MediaSidebarView(project: $project)
                }

                VSplitView {
                    PreviewCanvasView(project: project)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    if layout.isTimelineVisible {
                        TimelinePanelView(project: $project)
                    }
                }
                .frame(minWidth: 560)

                if layout.isInspectorVisible {
                    InspectorPanelView(project: project)
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
        .environment(environment)
        .focusedSceneValue(\.appEnvironment, environment)
        .onAppear {
            environment.attach(project: $project)
            environment.loadDocument(project)
            installPlaybackKeyMonitor()
        }
        .onDisappear {
            removePlaybackKeyMonitor()
        }
        .onChange(of: project.id) { _, _ in
            environment.loadDocument(project)
        }
    }

    // MARK: Space key play/pause

    private func installPlaybackKeyMonitor() {
        guard keyMonitor == nil else { return }
        let environment = environment

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Local event monitors are invoked on the main thread. Extract
            // plain values on the monitor thread, then hop for the decision.
            let keyCode = event.keyCode
            let modifiers = event.modifierFlags
            let isEditingText = event.window?.firstResponder is NSTextView
            let isModalSessionActive = NSApp.modalWindow != nil

            let consumed = MainActor.assumeIsolated {
                let router = PlaybackKeyRouter(
                    shouldHandle: { environment.playback.isReadyToPlay },
                    toggle: { environment.playback.togglePlayPause() }
                )
                return router.handle(
                    keyCode: keyCode,
                    modifiers: modifiers,
                    isEditingText: isEditingText,
                    isModalSessionActive: isModalSessionActive
                )
            }

            return consumed ? nil : event
        }
    }

    private func removePlaybackKeyMonitor() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
        }
        keyMonitor = nil
    }
}
