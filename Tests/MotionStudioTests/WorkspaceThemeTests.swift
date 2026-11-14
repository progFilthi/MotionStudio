import AppKit
import XCTest
@testable import MotionStudio

/// Tests ensuring every workspace chrome color defines cohesive light and
/// dark variants, so both appearances stay consistent as the design system
/// grows.
@MainActor
final class WorkspaceThemeTests: XCTestCase {
    // System appearance names always resolve; force unwraps are safe.
    private let aqua = NSAppearance(named: .aqua)!
    private let darkAqua = NSAppearance(named: .darkAqua)!

    private var paletteColors: [(String, AdaptiveColor)] {
        [
            ("windowBackground", WorkspaceTheme.Palette.windowBackground),
            ("panelBackground", WorkspaceTheme.Palette.panelBackground),
            ("toolbarBackground", WorkspaceTheme.Palette.toolbarBackground),
            ("canvasBackground", WorkspaceTheme.Palette.canvasBackground),
            ("hairline", WorkspaceTheme.Palette.hairline),
            ("textPrimary", WorkspaceTheme.Palette.textPrimary),
            ("textSecondary", WorkspaceTheme.Palette.textSecondary),
            ("textTertiary", WorkspaceTheme.Palette.textTertiary),
        ]
    }

    func testEveryChromeColorDefinesDistinctLightAndDarkVariants() {
        for (name, adaptiveColor) in paletteColors {
            XCTAssertNotEqual(
                adaptiveColor.light,
                adaptiveColor.dark,
                "\(name) must define distinct light and dark variants"
            )
        }
    }

    func testAppearanceResolutionSelectsTheExpectedVariant() {
        for (name, adaptiveColor) in paletteColors {
            XCTAssertEqual(
                adaptiveColor.components(for: aqua),
                adaptiveColor.light,
                "\(name) must resolve to its light variant in aqua appearance"
            )
            XCTAssertEqual(
                adaptiveColor.components(for: darkAqua),
                adaptiveColor.dark,
                "\(name) must resolve to its dark variant in darkAqua appearance"
            )
        }
    }

    func testPaletteComponentsAreWithinUnitRange() {
        for (name, adaptiveColor) in paletteColors {
            for (variantName, variant) in [("light", adaptiveColor.light), ("dark", adaptiveColor.dark)] {
                let components = [variant.red, variant.green, variant.blue, variant.alpha]
                XCTAssertGreaterThanOrEqual(
                    components.min() ?? -1, 0,
                    "\(name) \(variantName) has a component below 0"
                )
                XCTAssertLessThanOrEqual(
                    components.max() ?? 2, 1,
                    "\(name) \(variantName) has a component above 1"
                )
            }
        }
    }
}
