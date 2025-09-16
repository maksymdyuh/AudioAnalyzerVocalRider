#if os(macOS)
import SwiftUI
import AppKit

struct MouseTrackingView: NSViewRepresentable {
    var onMove: (CGFloat) -> Void // relative X in [0,1]

    func makeNSView(context: Context) -> NSView {
        let view = TrackingNSView()
        view.onMove = onMove
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let v = nsView as? TrackingNSView { v.onMove = onMove }
    }

    private final class TrackingNSView: NSView {
        var onMove: ((CGFloat) -> Void)?
        private var tracking: NSTrackingArea?

        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            if let t = tracking { removeTrackingArea(t) }
            let options: NSTrackingArea.Options = [.mouseMoved, .activeInActiveApp, .inVisibleRect, .enabledDuringMouseDrag]
            let area = NSTrackingArea(rect: self.bounds, options: options, owner: self, userInfo: nil)
            addTrackingArea(area)
            tracking = area
        }

        override var acceptsFirstResponder: Bool { true }
        override func mouseMoved(with event: NSEvent) {
            let loc = convert(event.locationInWindow, from: nil)
            let w = max(bounds.width, 1)
            let rel = max(0, min(1, loc.x / w))
            onMove?(rel)
            super.mouseMoved(with: event)
        }

        override func mouseDragged(with event: NSEvent) {
            mouseMoved(with: event)
            super.mouseDragged(with: event)
        }
    }
}
#endif
