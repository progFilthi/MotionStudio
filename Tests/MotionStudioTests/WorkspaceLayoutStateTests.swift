import XCTest
@testable import MotionStudio

/// Tests for workspace panel visibility state and its persistence.
@MainActor
final class WorkspaceLayoutStateTests: XCTestCase {
    private func makeDefaults() -> UserDefaults {
        let suiteName = "MotionStudioTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)
        defaults?.removePersistentDomain(forName: suiteName)
        return defaults ?? .standard
    }

    func testDefaultsShowAllPanels() {
        let layout = WorkspaceLayoutState(defaults: makeDefaults())

        XCTAssertTrue(layout.isMediaBrowserVisible)
        XCTAssertTrue(layout.isTimelineVisible)
        XCTAssertTrue(layout.isInspectorVisible)
    }

    func testTogglesChangeVisibility() {
        let layout = WorkspaceLayoutState(defaults: makeDefaults())

        layout.toggleMediaBrowser()
        layout.toggleTimeline()
        layout.toggleInspector()

        XCTAssertFalse(layout.isMediaBrowserVisible)
        XCTAssertFalse(layout.isTimelineVisible)
        XCTAssertFalse(layout.isInspectorVisible)
    }

    func testVisibilityPersistsAcrossInstances() {
        let defaults = makeDefaults()
        let first = WorkspaceLayoutState(defaults: defaults)

        first.toggleMediaBrowser()
        first.toggleInspector()
        XCTAssertTrue(first.isTimelineVisible)

        let second = WorkspaceLayoutState(defaults: defaults)
        XCTAssertFalse(second.isMediaBrowserVisible)
        XCTAssertTrue(second.isTimelineVisible)
        XCTAssertFalse(second.isInspectorVisible)
    }
}
