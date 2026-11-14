import Observation

/// The application composition root.
///
/// Shared services are constructed here and injected into the presentation
/// layer through the SwiftUI environment. Dependency construction must stay
/// out of SwiftUI view bodies, and there is deliberately no global service
/// locator (architecture §4).
///
/// Milestone 0 only requires diagnostics. Playback, persistence, editing
/// commands, and export services are added by later milestones.
@MainActor
@Observable
final class AppEnvironment {
    let errorReporter: AppErrorReporter

    /// The failure currently presented to the user, if any.
    private(set) var presentedError: ErrorPresentation?

    init(errorReporter: AppErrorReporter = AppErrorReporter()) {
        self.errorReporter = errorReporter
        AppLog.app.info("Application environment initialized")
    }

    /// Binding-friendly visibility of `presentedError`.
    var isPresentingError: Bool {
        get { presentedError != nil }
        set {
            guard !newValue else { return }
            presentedError = nil
        }
    }

    /// Reports a failed operation: logs technical detail and prepares a
    /// user-facing presentation.
    func report(_ error: Error, while performing: String) {
        presentedError = errorReporter.presentation(for: error, while: performing)
    }

    /// Clears the currently presented failure.
    func dismissError() {
        presentedError = nil
    }
}
