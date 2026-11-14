import SwiftUI

/// The shared visual language of the editing workspace.
///
/// The workspace is intentionally dark and restrained: near-neutral panels,
/// hairline separation, and a single accent color reserved for interactive
/// state. Keep every region consistent with these values instead of
/// introducing ad-hoc colors.
enum WorkspaceTheme {
    /// Window and content background.
    static let windowBackground = Color(red: 0.086, green: 0.086, blue: 0.094)

    /// Panel chrome behind headers and side panels.
    static let panelBackground = Color(red: 0.118, green: 0.118, blue: 0.129)

    /// Raised toolbar strip.
    static let toolbarBackground = Color(red: 0.153, green: 0.153, blue: 0.165)

    /// Canvas area behind the composition preview.
    static let canvasBackground = Color(red: 0.047, green: 0.047, blue: 0.055)

    /// Hairline separators between regions.
    static let hairline = Color.white.opacity(0.08)

    static let textPrimary = Color.white.opacity(0.92)
    static let textSecondary = Color.white.opacity(0.58)
    static let textTertiary = Color.white.opacity(0.34)

    /// Interactive accent color, defined in the asset catalog.
    static let accent = Color("AccentColor")
}
