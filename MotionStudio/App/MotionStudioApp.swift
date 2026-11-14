import SwiftUI

@main
struct MotionStudioApp: App {
    @State private var environment = AppEnvironment()

    var body: some Scene {
        WindowGroup {
            WorkspaceView()
                .environment(environment)
        }
        .defaultSize(width: 1400, height: 880)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Import Media…") {
                    Task { await environment.importMedia() }
                }
                .keyboardShortcut("i", modifiers: .command)
                .disabled(environment.mediaLibrary.isImporting)
            }
        }
    }
}
