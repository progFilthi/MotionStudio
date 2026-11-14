import XCTest
@testable import MotionStudio

/// Tests for the space-key play/pause routing decision logic.
final class PlaybackKeyRouterTests: XCTestCase {
    private func makeRouter(
        shouldHandle: Bool = true,
        onToggle: @escaping () -> Void
    ) -> PlaybackKeyRouter {
        PlaybackKeyRouter(shouldHandle: { shouldHandle }, toggle: onToggle)
    }

    func testPlainSpaceIsConsumedAsPlayPause() {
        var toggled = false
        let router = makeRouter { toggled = true }

        let consumed = router.handle(
            keyCode: PlaybackKeyRouter.spaceKeyCode,
            modifiers: [],
            isEditingText: false,
            isModalSessionActive: false
        )

        XCTAssertTrue(consumed)
        XCTAssertTrue(toggled)
    }

    func testOtherKeysFallThrough() {
        let router = makeRouter { XCTFail("Only space should toggle") }

        for keyCode: UInt16 in [13, 36, 123, 125, 49 + 1] {
            XCTAssertFalse(
                router.handle(keyCode: keyCode, modifiers: [], isEditingText: false, isModalSessionActive: false),
                "Key code \(keyCode) must fall through"
            )
        }
    }

    func testModifiedSpaceFallsThrough() {
        let router = makeRouter { XCTFail("Modified space must not toggle") }

        for modifiers: NSEvent.ModifierFlags in [.command, .option, .control, .shift] {
            XCTAssertFalse(
                router.handle(
                    keyCode: PlaybackKeyRouter.spaceKeyCode,
                    modifiers: modifiers,
                    isEditingText: false,
                    isModalSessionActive: false
                ),
                "Space with \(modifiers) must fall through"
            )
        }
    }

    func testSpaceDuringTextEditingFallsThrough() {
        var toggled = false
        let router = makeRouter { toggled = true }

        XCTAssertFalse(
            router.handle(
                keyCode: PlaybackKeyRouter.spaceKeyCode,
                modifiers: [],
                isEditingText: true,
                isModalSessionActive: false
            )
        )
        XCTAssertFalse(toggled)
    }

    func testSpaceDuringModalSessionFallsThrough() {
        var toggled = false
        let router = makeRouter { toggled = true }

        XCTAssertFalse(
            router.handle(
                keyCode: PlaybackKeyRouter.spaceKeyCode,
                modifiers: [],
                isEditingText: false,
                isModalSessionActive: true
            )
        )
        XCTAssertFalse(toggled)
    }

    func testSpaceWhenPlaybackUnavailableFallsThrough() {
        var toggled = false
        let router = makeRouter(shouldHandle: false) { toggled = true }

        XCTAssertFalse(
            router.handle(
                keyCode: PlaybackKeyRouter.spaceKeyCode,
                modifiers: [],
                isEditingText: false,
                isModalSessionActive: false
            )
        )
        XCTAssertFalse(toggled)
    }
}
