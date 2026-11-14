import Foundation

/// Visual transform of a clip or layer.
///
/// Coordinate convention (architecture §5.7, defined once here):
///
/// - Position and anchor are normalized composition coordinates in
///   `0...1`, with the origin at the bottom-left of the composition and
///   the Y axis increasing **upward**. `(0.5, 0.5)` is the composition
///   center. Rendering boundaries convert to device coordinates, which
///   flip Y.
/// - Scale is a multiplier around the anchor point.
/// - Rotation is counterclockwise degrees.
///
/// Missing keys on decode fall back to the documented defaults so older
/// project versions stay readable as the schema grows.
nonisolated struct Transform: Codable, Hashable, Sendable {
    var positionX: Double
    var positionY: Double
    var scaleX: Double
    var scaleY: Double
    var rotationDegrees: Double
    var anchorX: Double
    var anchorY: Double

    static let identity = Transform()

    init(
        positionX: Double = 0.5,
        positionY: Double = 0.5,
        scaleX: Double = 1,
        scaleY: Double = 1,
        rotationDegrees: Double = 0,
        anchorX: Double = 0.5,
        anchorY: Double = 0.5
    ) {
        self.positionX = positionX
        self.positionY = positionY
        self.scaleX = scaleX
        self.scaleY = scaleY
        self.rotationDegrees = rotationDegrees
        self.anchorX = anchorX
        self.anchorY = anchorY
    }

    private enum CodingKeys: String, CodingKey {
        case positionX
        case positionY
        case scaleX
        case scaleY
        case rotationDegrees
        case anchorX
        case anchorY
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = Transform.identity
        self.positionX = try container.decodeIfPresent(Double.self, forKey: .positionX) ?? defaults.positionX
        self.positionY = try container.decodeIfPresent(Double.self, forKey: .positionY) ?? defaults.positionY
        self.scaleX = try container.decodeIfPresent(Double.self, forKey: .scaleX) ?? defaults.scaleX
        self.scaleY = try container.decodeIfPresent(Double.self, forKey: .scaleY) ?? defaults.scaleY
        self.rotationDegrees = try container.decodeIfPresent(Double.self, forKey: .rotationDegrees) ?? defaults.rotationDegrees
        self.anchorX = try container.decodeIfPresent(Double.self, forKey: .anchorX) ?? defaults.anchorX
        self.anchorY = try container.decodeIfPresent(Double.self, forKey: .anchorY) ?? defaults.anchorY
    }
}
