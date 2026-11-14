import Foundation

/// An RGBA color with components in the 0...1 range.
///
/// Component values are clamped on construction so persisted colors are
/// always in range. Encoding is explicit and stable: `r`, `g`, `b`, `a`.
nonisolated struct RGBAColor: Codable, Hashable, Sendable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double

    static let black = RGBAColor(red: 0, green: 0, blue: 0, alpha: 1)
    static let white = RGBAColor(red: 1, green: 1, blue: 1, alpha: 1)

    init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = RGBAColor.clamped(red)
        self.green = RGBAColor.clamped(green)
        self.blue = RGBAColor.clamped(blue)
        self.alpha = RGBAColor.clamped(alpha)
    }

    private static func clamped(_ value: Double) -> Double {
        if value.isNaN { return 0 }
        return min(max(value, 0), 1)
    }

    private enum CodingKeys: String, CodingKey {
        case red = "r"
        case green = "g"
        case blue = "b"
        case alpha = "a"
    }
}
