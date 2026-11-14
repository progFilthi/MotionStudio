import AppKit
import SwiftUI

/// Preview overlay for one active text layer (roadmap Milestone 3).
///
/// **This is a presentation-layer approximation, not the render
/// engine.** The overlay maps composition coordinates onto the preview
/// canvas with SwiftUI transforms:
///
/// - Position maps onto the aspect-fit rect of the composition canvas
///   (Y flips: the domain origin is bottom-left, SwiftUI's is top-left).
/// - The text's center is placed at the position point; scale and
///   rotation pivot around the transform's anchor, interpreted relative
///   to the text's own bounds (the default anchor 0.5, 0.5 is the
///   center). Precise text measurement and canvas-true anchors arrive
///   with the compositing milestone's render engine.
/// - Rotation negates: domain rotation is counterclockwise, SwiftUI's
///   angle is clockwise.
///
/// When the underlying video's aspect differs from the composition's,
/// the letterboxed video and this overlay rect diverge; the render
/// engine composites at composition resolution and will not.
struct TextOverlayView: View {
    let overlay: TextOverlay
    let contentRect: CGRect
    let compositionSize: CGSize

    var body: some View {
        if case .text(let source) = overlay.clip.source {
            content(for: source)
        }
    }

    private func content(for source: TextSource) -> some View {
        let typography = source.typography
        let clip = overlay.clip

        // Composition pixels scale into on-screen points by the same
        // factor as the content rect.
        let displayScale = contentRect.width / max(CGFloat(compositionSize.width), 1)
        let displayFontSize = max(1, typography.fontSize * displayScale)
        let displayTracking = typography.tracking * displayScale

        let position = CGPoint(
            x: contentRect.minX + clip.transform.positionX * contentRect.width,
            y: contentRect.minY + (1 - clip.transform.positionY) * contentRect.height
        )
        // Domain anchor Y increases upward; SwiftUI anchor Y increases
        // downward.
        let anchor = UnitPoint(x: clip.transform.anchorX, y: 1 - clip.transform.anchorY)
        let scaleX = max(0, overlay.values.scaleX)
        let scaleY = max(0, overlay.values.scaleY)
        let opacity = min(max(overlay.values.opacity, 0), 1)

        return Text(source.text)
            .font(font(for: typography, size: displayFontSize))
            .kerning(displayTracking)
            .multilineTextAlignment(swiftUIAlignment(for: typography.alignment))
            .foregroundStyle(Color(
                red: typography.fillColor.red,
                green: typography.fillColor.green,
                blue: typography.fillColor.blue,
                opacity: typography.fillColor.alpha
            ))
            .fixedSize(horizontal: false, vertical: true)
            .scaleEffect(x: scaleX, y: scaleY, anchor: anchor)
            .rotationEffect(.degrees(-clip.transform.rotationDegrees), anchor: anchor)
            .opacity(opacity)
            .position(position)
    }

    private func font(for typography: Typography, size: CGFloat) -> Font {
        let base: Font = typography.fontName == "System"
            ? .system(size: size)
            : .custom(typography.fontName, size: size)
        return base.weight(fontWeight(for: typography.weight))
    }

    private func fontWeight(for weight: FontWeight) -> Font.Weight {
        switch weight {
        case .regular: return .regular
        case .medium: return .medium
        case .semibold: return .semibold
        case .bold: return .bold
        }
    }

    private func swiftUIAlignment(for alignment: MotionStudio.TextAlignment) -> SwiftUI.TextAlignment {
        switch alignment {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }
}

// MARK: Color adapters

nonisolated extension RGBAColor {
    /// The SwiftUI color for a domain color. Presentation-only mapping.
    var swiftUIColor: Color {
        Color(
            .sRGB,
            red: red,
            green: green,
            blue: blue,
            opacity: alpha
        )
    }
}

nonisolated extension Color {
    /// The domain color for a SwiftUI color, converted through sRGB so
    /// persisted components match what the color picker showed.
    init(_ domain: RGBAColor) {
        self.init(
            red: domain.red,
            green: domain.green,
            blue: domain.blue,
            opacity: domain.alpha
        )
    }
}

nonisolated extension RGBAColor {
    /// Reads a SwiftUI color into domain components via sRGB. Used by
    /// the typography fill color picker.
    init(_ color: Color) {
        let nsColor = NSColor(color).usingColorSpace(.sRGB)
        self.init(
            red: nsColor.map { Double($0.redComponent) } ?? 1,
            green: nsColor.map { Double($0.greenComponent) } ?? 1,
            blue: nsColor.map { Double($0.blueComponent) } ?? 1,
            alpha: nsColor.map { Double($0.alphaComponent) } ?? 1
        )
    }
}
