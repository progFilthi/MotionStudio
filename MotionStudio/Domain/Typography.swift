import Foundation

/// Font weight for text layers. Explicit raw values keep the project
/// format stable.
nonisolated enum FontWeight: String, Codable, CaseIterable, Hashable, Sendable {
    case regular
    case medium
    case semibold
    case bold

    var displayName: String {
        switch self {
        case .regular: return "Regular"
        case .medium: return "Medium"
        case .semibold: return "Semibold"
        case .bold: return "Bold"
        }
    }
}

/// Horizontal alignment of multi-line text.
nonisolated enum TextAlignment: String, Codable, CaseIterable, Hashable, Sendable {
    case leading
    case center
    case trailing

    var displayName: String {
        switch self {
        case .leading: return "Leading"
        case .center: return "Center"
        case .trailing: return "Trailing"
        }
    }
}

/// Typography of a text layer (architecture §5.8).
///
/// Font size and tracking are in composition pixels; rendering
/// boundaries scale them when the composition is displayed at a
/// different size. Missing keys on decode fall back to the documented
/// defaults so the schema can grow without breaking old files.
nonisolated struct Typography: Codable, Hashable, Sendable {
    /// Font family name, or `"System"` for the system font.
    var fontName: String
    var fontSize: Double
    var weight: FontWeight
    var fillColor: RGBAColor
    var alignment: TextAlignment
    /// Letter spacing in composition pixels.
    var tracking: Double

    static let `default` = Typography()

    init(
        fontName: String = "System",
        fontSize: Double = 96,
        weight: FontWeight = .regular,
        fillColor: RGBAColor = .white,
        alignment: TextAlignment = .center,
        tracking: Double = 0
    ) {
        self.fontName = fontName
        self.fontSize = fontSize
        self.weight = weight
        self.fillColor = fillColor
        self.alignment = alignment
        self.tracking = tracking
    }

    private enum CodingKeys: String, CodingKey {
        case fontName
        case fontSize
        case weight
        case fillColor
        case alignment
        case tracking
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = Typography.default
        fontName = try container.decodeIfPresent(String.self, forKey: .fontName) ?? defaults.fontName
        fontSize = try container.decodeIfPresent(Double.self, forKey: .fontSize) ?? defaults.fontSize
        weight = try container.decodeIfPresent(FontWeight.self, forKey: .weight) ?? defaults.weight
        fillColor = try container.decodeIfPresent(RGBAColor.self, forKey: .fillColor) ?? defaults.fillColor
        alignment = try container.decodeIfPresent(TextAlignment.self, forKey: .alignment) ?? defaults.alignment
        tracking = try container.decodeIfPresent(Double.self, forKey: .tracking) ?? defaults.tracking

        guard fontSize.isFinite, fontSize > 0 else {
            throw DecodingError.dataCorruptedError(
                forKey: .fontSize,
                in: container,
                debugDescription: "Typography font size must be positive (got \(fontSize))."
            )
        }
        guard tracking.isFinite else {
            throw DecodingError.dataCorruptedError(
                forKey: .tracking,
                in: container,
                debugDescription: "Typography tracking must be finite."
            )
        }
    }

    /// Validates the values after programmatic edits.
    func validate() throws {
        guard fontSize.isFinite, fontSize > 0 else {
            throw ProjectValidationError.invalidTypography("Font size must be positive.")
        }
        guard tracking.isFinite else {
            throw ProjectValidationError.invalidTypography("Tracking must be finite.")
        }
        guard !fontName.isEmpty else {
            throw ProjectValidationError.invalidTypography("Font name must not be empty.")
        }
    }
}
