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
    }
}
