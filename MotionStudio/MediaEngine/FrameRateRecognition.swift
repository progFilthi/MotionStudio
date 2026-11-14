import AVFoundation
import Foundation

/// Recognizes common frame rates, preserving fractional NTSC rates.
nonisolated enum FrameRateRecognition {
    /// Rates matched within `tolerance` map to their canonical rational
    /// form (e.g. 29.97 → 30000/1001); near-integer rates map to n/1;
    /// anything else falls back to a thousandths denominator.
    static func frameRate(approximating framesPerSecond: Float) -> FrameRate? {
        guard framesPerSecond.isFinite, framesPerSecond > 0 else { return nil }
        let rate = Double(framesPerSecond)

        let fractional: [(target: Double, frameRate: FrameRate)] = [
            (24000.0 / 1001.0, .exact(24000, over: 1001)),
            (30000.0 / 1001.0, .exact(30000, over: 1001)),
            (60000.0 / 1001.0, .exact(60000, over: 1001)),
        ]
        for candidate in fractional where abs(rate - candidate.target) < 0.02 {
            return candidate.frameRate
        }

        let rounded = rate.rounded()
        if abs(rate - rounded) < 0.01 {
            return FrameRate.exact(Int32(rounded), over: 1)
        }

        // Unknown fractional rate: keep three decimals of fidelity.
        let thousandths = Int32((rate * 1000).rounded())
        guard thousandths > 0 else { return nil }
        return FrameRate.exact(thousandths, over: 1000)
    }
}
