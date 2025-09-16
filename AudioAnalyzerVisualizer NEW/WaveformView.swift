//
//  WaveformView.swift
//  AudioAnalyzerVisualizer NEW
//
//  Renders a simple vertical-line waveform from dBFS samples with grid and center line.
//

import SwiftUI

struct WaveformView: View {
    let samplesDB: [Double] // negative dBFS values
    var lineColor: Color = .accentColor
    var showGrid: Bool = true
    var amplitudeScale: CGFloat = 1.0 // visual vertical zoom
    var timeZoom: CGFloat = 1.0       // horizontal zoom factor (1 = full track)
    var timeStart: CGFloat = 0.0      // normalized left edge [0, 1 - 1/timeZoom]

    private func amplitude(from dB: Double) -> CGFloat {
        let linear = pow(10.0, dB / 20.0)
        return CGFloat(max(0, min(1, linear))) // 0..1
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let n = max(samplesDB.count, 1)
            let f = max(1.0 / max(timeZoom, 0.000001), 0.000001)
            let startNorm = max(0.0, min(timeStart, 1.0 - f))
            let endNorm = min(1.0, startNorm + f)
            let iStart = Int(floor(Double(n) * Double(startNorm)))
            let iEnd = Int(ceil(Double(n) * Double(endNorm)))
            let visibleCount = max(1, iEnd - iStart)
            let step = w / CGFloat(visibleCount)

            Canvas { context, size in
                if showGrid {
                    // Center line
                    var center = Path()
                    center.move(to: CGPoint(x: 0, y: h / 2))
                    center.addLine(to: CGPoint(x: w, y: h / 2))
                    context.stroke(center, with: .color(.gray.opacity(0.4)), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))

                    // Vertical grid lines (time)
                    let columns = 10
                    for i in 0...columns {
                        let x = CGFloat(i) * w / CGFloat(columns)
                        var g = Path()
                        g.move(to: CGPoint(x: x, y: 0))
                        g.addLine(to: CGPoint(x: x, y: h))
                        context.stroke(g, with: .color(.gray.opacity(0.15)), lineWidth: 1)
                    }

                }

                // Waveform for visible range only
                var path = Path()
                if iStart < iEnd {
                    for i in iStart..<iEnd {
                        let idx = i
                        if idx < samplesDB.count {
                            let x = CGFloat(i - iStart) * step
                            let amp = amplitude(from: samplesDB[idx])
                            let lineHeight = min(h/2.0, amp * amplitudeScale * (h / 2.0))
                            let yTop = (h / 2.0) - lineHeight
                            let yBottom = (h / 2.0) + lineHeight
                            path.move(to: CGPoint(x: x, y: yTop))
                            path.addLine(to: CGPoint(x: x, y: yBottom))
                        }
                    }
                }
                context.stroke(path, with: .color(lineColor), lineWidth: max(1, step * 0.85))
            }
        }
        .accessibilityLabel("Waveform")
    }
}
