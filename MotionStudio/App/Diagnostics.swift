import Foundation
import os

/// Stable logging identity for the application.
///
/// All subsystem loggers share one subsystem so Console.app filtering stays
/// simple. Add one category per architecture subsystem as it appears; do not
/// log secrets, private media contents, or user data.
enum AppLog {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.motionstudio.MotionStudio"

    /// Application lifecycle and composition-root events.
    static let app = Logger(subsystem: subsystem, category: "app")

    /// Workspace presentation events.
    static let workspace = Logger(subsystem: subsystem, category: "workspace")
}

/// A user-facing description of a failure, kept separate from technical
/// detail.
///
/// Technical diagnostics belong in logs (see `AppErrorReporter`); this type
/// carries only what a user needs to understand what happened and whether
/// their data is safe.
struct ErrorPresentation: Identifiable, Sendable {
    let id = UUID()
    let title: String
    let message: String
}

extension ErrorPresentation: Equatable {
    static func == (lhs: ErrorPresentation, rhs: ErrorPresentation) -> Bool {
        lhs.title == rhs.title && lhs.message == rhs.message
    }
}

/// Converts thrown errors into user-facing presentations and logs the
/// technical detail.
///
/// This is the single reporting path for application errors: user-facing
/// surfaces receive an `ErrorPresentation` through the application
/// environment, while full context is written to the unified log. Errors that
/// conform to `LocalizedError` can supply their own user-facing wording.
struct AppErrorReporter: Sendable {
    func presentation(for error: Error, while performing: String) -> ErrorPresentation {
        let localized = error as? LocalizedError
        let title = localized?.errorDescription ?? "Something went wrong"
        let message = localized?.failureReason
            ?? localized?.recoverySuggestion
            ?? error.localizedDescription

        AppLog.app.error(
            "Error while \(performing, privacy: .public): \(String(describing: error), privacy: .public)"
        )

        return ErrorPresentation(title: title, message: message)
    }
}
