import AppKit
import Observation

/// The application composition root.
///
/// Shared services are constructed here and injected into the presentation
/// layer through the SwiftUI environment. Dependency construction must stay
/// out of SwiftUI view bodies, and there is deliberately no global service
/// locator (architecture §4).
@MainActor
@Observable
final class AppEnvironment {
    let errorReporter: AppErrorReporter
    let mediaImporter: MediaImporter
    let playback: PlaybackController
    let mediaLibrary: MediaLibraryState

    /// The failure currently presented to the user, if any.
    private(set) var presentedError: ErrorPresentation?

    init(errorReporter: AppErrorReporter = AppErrorReporter()) {
        self.errorReporter = errorReporter
        self.mediaImporter = MediaImporter()

        let playback = PlaybackController()
        self.playback = playback
        self.mediaLibrary = MediaLibraryState()

        playback.onError = { [weak self] error in
            self?.report(error, while: "playing media")
        }

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

    // MARK: Media import (Milestone 1)

    /// Opens the import panel and inspects each selected file. Cancelled
    /// panels are not errors; individual failures are reported while the
    /// remaining files continue.
    func importMedia() async {
        guard !mediaLibrary.isImporting else { return }
        mediaLibrary.isImporting = true
        defer { mediaLibrary.isImporting = false }

        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = MediaFormats.allowedContentTypes
        panel.message = "Choose videos to add to the media library"
        panel.prompt = "Import"

        guard panel.runModal() == .OK, !panel.urls.isEmpty else { return }

        var firstImported: MediaLibraryItem?
        for url in panel.urls {
            do {
                let info = try await mediaImporter.inspect(url: url)
                let item = MediaLibraryItem(
                    id: UUID(),
                    name: url.deletingPathExtension().lastPathComponent,
                    info: info
                )
                mediaLibrary.add(item)
                if firstImported == nil {
                    firstImported = item
                }
            } catch {
                report(error, while: "importing '\(url.lastPathComponent)'")
            }
        }

        if let item = firstImported {
            selectMedia(item)
        }
    }

    /// Selects a library item and loads it into the preview.
    func selectMedia(_ item: MediaLibraryItem) {
        mediaLibrary.selectedItemID = item.id
        playback.load(url: item.info.url)
    }
}
