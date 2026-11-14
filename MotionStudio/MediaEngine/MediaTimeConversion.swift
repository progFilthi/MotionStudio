import AVFoundation

/// Conversions between domain rational time and `CMTime` (architecture
/// §5.3: conversion happens at AVFoundation boundaries only).
nonisolated extension MediaTime {
    /// The `CMTime` with the same components.
    var cmTime: CMTime {
        CMTime(value: CMTimeValue(value), timescale: CMTimeScale(timescale))
    }

    /// Builds domain time from a `CMTime`. Invalid times map to zero;
    /// the components are preserved exactly.
    init(cmTime: CMTime) {
        guard cmTime.isNumeric, cmTime.timescale > 0 else {
            self = .zero
            return
        }
        self = .exact(Int64(cmTime.value), over: CMTimeScale(cmTime.timescale))
    }
}
