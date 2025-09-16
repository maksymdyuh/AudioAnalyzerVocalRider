#if os(macOS)
import SwiftUI
import AppKit

struct WheelZoomView: NSViewRepresentable {
    var onZoom: (_ scaleDelta: CGFloat, _ cursorRelX: CGFloat) -> Void
    var onPan: (_ deltaRel: CGFloat) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = WheelNSView()
        view.onZoom = onZoom
        view.onPan = onPan
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let v = nsView as? WheelNSView {
            v.onZoom = onZoom
            v.onPan = onPan
        }
    }

    final class WheelNSView: NSView {
        var onZoom: ((_ scaleDelta: CGFloat, _ cursorRelX: CGFloat) -> Void)?
        var onPan: ((_ deltaRel: CGFloat) -> Void)?

        override func scrollWheel(with event: NSEvent) {
            let loc = convert(event.locationInWindow, from: nil)
            let w = max(bounds.width, 1)
            let relX = max(0, min(1, loc.x / w))

            // Natural behavior: horizontal scroll pans, vertical scroll zooms.
            // If both present, choose dominant axis. Shift can force pan if desired.
            let dx = event.scrollingDeltaX
            let dy = event.scrollingDeltaY
            let dominantIsHorizontal = abs(dx) > abs(dy)
            if dominantIsHorizontal || event.modifierFlags.contains(.shift) {
                // Horizontal pan (fallback to vertical delta if X is zero)
                let useDX = dx != 0 ? dx : -dy
                let deltaRel = CGFloat(useDX) / w
                onPan?(deltaRel)
            } else {
                // Vertical zoom
                let scaleDelta = pow(1.08, dy / 10.0) // tune factor
                onZoom?(scaleDelta, relX)
            }
        }

        override var acceptsFirstResponder: Bool { true }
    }
}
#endif
