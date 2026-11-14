import Foundation
import Observation
import os

/// Presentation state for workspace panel visibility.
///
/// This is deliberately presentation-only state (architecture §4): it never
/// represents project data. Panel choices persist across launches through
/// `UserDefaults`.
@MainActor
@Observable
final class WorkspaceLayoutState {
    private enum Keys {
        static let mediaBrowser = "workspace.mediaBrowserVisible"
        static let timeline = "workspace.timelineVisible"
        static let inspector = "workspace.inspectorVisible"
    }

    private let defaults: UserDefaults

    var isMediaBrowserVisible: Bool {
        didSet { defaults.set(isMediaBrowserVisible, forKey: Keys.mediaBrowser) }
    }

    var isTimelineVisible: Bool {
        didSet { defaults.set(isTimelineVisible, forKey: Keys.timeline) }
    }

    var isInspectorVisible: Bool {
        didSet { defaults.set(isInspectorVisible, forKey: Keys.inspector) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        isMediaBrowserVisible = defaults.object(forKey: Keys.mediaBrowser) as? Bool ?? true
        isTimelineVisible = defaults.object(forKey: Keys.timeline) as? Bool ?? true
        isInspectorVisible = defaults.object(forKey: Keys.inspector) as? Bool ?? true
    }

    func toggleMediaBrowser() {
        isMediaBrowserVisible.toggle()
        AppLog.workspace.debug("Media browser \(self.isMediaBrowserVisible ? "shown" : "hidden", privacy: .public)")
    }

    func toggleTimeline() {
        isTimelineVisible.toggle()
        AppLog.workspace.debug("Timeline \(self.isTimelineVisible ? "shown" : "hidden", privacy: .public)")
    }

    func toggleInspector() {
        isInspectorVisible.toggle()
        AppLog.workspace.debug("Inspector \(self.isInspectorVisible ? "shown" : "hidden", privacy: .public)")
    }
}
