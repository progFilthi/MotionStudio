import AppKit
import SwiftUI

/// RGBA components for one appearance variant of a theme color.
struct PaletteComponents: Equatable, Sendable {
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double

    init(_ red: Double, _ green: Double, _ blue: Double, _ alpha: Double = 1.0) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }
}

/// A workspace color defined once with explicit light and dark variants so
/// both appearances stay cohesive as the design system grows.
struct AdaptiveColor: Sendable {
    let light: PaletteComponents
    let dark: PaletteComponents

    /// The variant selected for an appearance.
    func components(for appearance: NSAppearance) -> PaletteComponents {
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
    }

    /// The SwiftUI color, resolving against the effective appearance at use
    /// time so the workspace updates live when the system appearance
    /// changes.
    var color: Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let components = self.components(for: appearance)
            return NSColor(
                srgbRed: components.red,
                green: components.green,
                blue: components.blue,
                alpha: components.alpha
            )
        })
    }
}

/// The shared visual language of the editing workspace.
///
/// The workspace is restrained in either appearance: near-neutral surfaces,
/// hairline separation, and a single accent color reserved for interactive
/// state. Every chrome color carries explicit light and dark values in
/// `Palette`; the app follows the system appearance. Dark remains the
/// flagship look for the editor.
enum WorkspaceTheme {
    /// The single source for all light/dark chrome color values. Tests read
    /// this directly to keep both palettes cohesive.
    enum Palette {
        static let windowBackground = AdaptiveColor(
            light: PaletteComponents(0.925, 0.925, 0.937),
            dark: PaletteComponents(0.086, 0.086, 0.094)
        )

        static let panelBackground = AdaptiveColor(
            light: PaletteComponents(0.973, 0.973, 0.980),
            dark: PaletteComponents(0.118, 0.118, 0.129)
        )

        static let toolbarBackground = AdaptiveColor(
            light: PaletteComponents(0.882, 0.882, 0.898),
            dark: PaletteComponents(0.153, 0.153, 0.165)
        )

        static let canvasBackground = AdaptiveColor(
            light: PaletteComponents(1.000, 1.000, 1.000),
            dark: PaletteComponents(0.047, 0.047, 0.055)
        )

        static let hairline = AdaptiveColor(
            light: PaletteComponents(0.000, 0.000, 0.000, 0.12),
            dark: PaletteComponents(1.000, 1.000, 1.000, 0.08)
        )

        static let textPrimary = AdaptiveColor(
            light: PaletteComponents(0.000, 0.000, 0.000, 0.85),
            dark: PaletteComponents(1.000, 1.000, 1.000, 0.92)
        )

        static let textSecondary = AdaptiveColor(
            light: PaletteComponents(0.000, 0.000, 0.000, 0.55),
            dark: PaletteComponents(1.000, 1.000, 1.000, 0.58)
        )

        static let textTertiary = AdaptiveColor(
            light: PaletteComponents(0.000, 0.000, 0.000, 0.36),
            dark: PaletteComponents(1.000, 1.000, 1.000, 0.34)
        )
    }

    /// Window and content background.
    static var windowBackground: Color { Palette.windowBackground.color }

    /// Panel chrome behind headers and side panels.
    static var panelBackground: Color { Palette.panelBackground.color }

    /// Raised toolbar strip.
    static var toolbarBackground: Color { Palette.toolbarBackground.color }

    /// Canvas area behind the composition preview.
    static var canvasBackground: Color { Palette.canvasBackground.color }

    /// Hairline separators between regions.
    static var hairline: Color { Palette.hairline.color }

    static var textPrimary: Color { Palette.textPrimary.color }
    static var textSecondary: Color { Palette.textSecondary.color }
    static var textTertiary: Color { Palette.textTertiary.color }

    /// Interactive accent color, defined in the asset catalog.
    static var accent: Color { Color("AccentColor") }
}
