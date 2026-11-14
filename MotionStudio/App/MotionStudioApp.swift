import SwiftUI

@main
struct MotionStudioApp: App {
    /// The environment of the focused document window; commands must
    /// resolve per-window because each window owns its environment.
    @FocusedValue(\.appEnvironment) private var environment: AppEnvironment?

    var body: some Scene {
        DocumentGroup(newDocument: ProjectDocument()) { file in
            WorkspaceView(project: file.$document.project)
        }
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Import Media…") {
                    if let environment {
                        Task { await environment.importMedia() }
                    }
                }
                .keyboardShortcut("i", modifiers: .command)
                .disabled(environment == nil)

                Button("Add Text Layer") {
                    environment?.addTextClip()
                }
                .keyboardShortcut("t", modifiers: .command)
                .disabled(environment == nil)
            }
        }
    }
}
