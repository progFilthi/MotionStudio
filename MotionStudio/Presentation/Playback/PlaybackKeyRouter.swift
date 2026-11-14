import AppKit
import Foundation

/// Routes the space key to play/pause.
///
/// Pure decision logic, separated from the NSEvent monitor so it can be
/// unit-tested. Space is consumed only for a plain, unmodified keypress
/// outside text editing and modal sessions while playback is available;
/// otherwise it falls through to the normal responder chain (scrolling,
/// Quick Look in panels, focused-button activation).
nonisolated struct PlaybackKeyRouter {
    let shouldHandle: () -> Bool
    let toggle: () -> Void

    /// The virtual key code for the space bar (kVK_Space).
    nonisolated static let spaceKeyCode: UInt16 = 49

    /// Returns true when the key event was consumed as play/pause.
    func handle(
        keyCode: UInt16,
        modifiers: NSEvent.ModifierFlags,
        isEditingText: Bool,
        isModalSessionActive: Bool
    ) -> Bool {
        let isPlainSpace = keyCode == Self.spaceKeyCode
            && modifiers.intersection([.command, .option, .control, .shift]).isEmpty
        guard isPlainSpace, !isEditingText, !isModalSessionActive, shouldHandle() else {
            return false
        }
        toggle()
        return true
    }
}
