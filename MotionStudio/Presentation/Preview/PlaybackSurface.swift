import AVFoundation
import AppKit
import SwiftUI

/// Native preview surface: an `AVPlayerLayer`-backed view wrapped for
/// SwiftUI (architecture §7.2 — AVPlayer with a native video surface).
struct AVPlayerSurface: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> PlayerLayerView {
        let view = PlayerLayerView(frame: .zero)
        view.player = player
        return view
    }

    func updateNSView(_ nsView: PlayerLayerView, context: Context) {
        if nsView.player !== player {
            nsView.player = player
        }
    }
}

/// NSView whose backing layer is an `AVPlayerLayer`.
final class PlayerLayerView: NSView {
    var player: AVPlayer? {
        get { playerLayer?.player }
        set { playerLayer?.player = newValue }
    }

    private var playerLayer: AVPlayerLayer? { layer as? AVPlayerLayer }

    override func makeBackingLayer() -> CALayer {
        let layer = AVPlayerLayer()
        layer.videoGravity = .resizeAspect
        return layer
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("PlaybackSurface is created in code only")
    }
}
