import Foundation

/// The clip properties that can be keyframed (architecture §5.9).
///
/// Milestone 3 supports scale and opacity; position, rotation, and
/// anchor animation arrive with the compositing milestone. Serialized
/// raw values are stable project-format identifiers.
nonisolated enum AnimatableProperty: String, Codable, CaseIterable, Hashable, Sendable {
    case scaleX
    case scaleY
    case opacity

    /// Human-readable name for inspector and timeline UI.
    var displayName: String {
        switch self {
        case .scaleX: return "Scale X"
        case .scaleY: return "Scale Y"
        case .opacity: return "Opacity"
        }
    }

    /// The value a clip uses when the property has no animation.
    func staticValue(of clip: Clip) -> Double {
        switch self {
        case .scaleX: return clip.transform.scaleX
        case .scaleY: return clip.transform.scaleY
        case .opacity: return clip.opacity
        }
    }
}
