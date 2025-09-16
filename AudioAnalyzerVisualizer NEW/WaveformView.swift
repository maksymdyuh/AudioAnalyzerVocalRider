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

            Canvas { context, size in
                if showGrid {
                    // Center line
                    var center = Path()
                    center.move(to: CGPoint(x: 0, y: h / 2))
                    center.addLine(to: CGPoint(x: w, y: h / 2))
                    context.stroke(center, with: .color(.gray.opacity(0.4)), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))

                    // Subtle vertical guides (fixed columns as a background reference)
                    let columns = 8
                    for i in 0...columns {
                        let x = CGFloat(i) * w / CGFloat(columns)
                        var g = Path()
                        g.move(to: CGPoint(x: x, y: 0))
                        g.addLine(to: CGPoint(x: x, y: h))
                        context.stroke(g, with: .color(.gray.opacity(0.12)), lineWidth: 1)
                    }
                }

                // Build a detailed filled waveform silhouette using per-pixel min/max aggregation
                let widthInt = max(1, Int(w.rounded(.down)))
                if widthInt > 0 && iStart < iEnd {
                    var minAmp = Array(repeating: CGFloat(1.0), count: widthInt)
                    var maxAmp = Array(repeating: CGFloat(0.0), count: widthInt)

                    let denom = max(CGFloat(visibleCount - 1), 1)
                    let halfH = h / 2.0

                    for i in iStart..<iEnd {
                        let idx = i
                        if idx < samplesDB.count {
                            let amp = min(1.0, amplitude(from: samplesDB[idx]) * amplitudeScale)
                            let xf = (CGFloat(i - iStart) / denom) * max(w - 1, 1)
                            let bx = min(widthInt - 1, max(0, Int(xf)))
                            minAmp[bx] = min(minAmp[bx], amp)
                            maxAmp[bx] = max(maxAmp[bx], amp)
                        }
                    }

                    var polygon = Path()
                    var topPoints: [CGPoint] = []
                    var bottomPoints: [CGPoint] = []

                    for x in 0..<widthInt {
                        let a = maxAmp[x]
                        if a > 0 { // valid bucket
                            let cx = CGFloat(x) + 0.5
                            let yTop = halfH - a * halfH
                            let yBottom = halfH + a * halfH
                            topPoints.append(CGPoint(x: cx, y: yTop))
                            bottomPoints.append(CGPoint(x: cx, y: yBottom))
                        }
                    }

                    if let first = topPoints.first {
                        polygon.move(to: first)
                        for p in topPoints.dropFirst() { polygon.addLine(to: p) }
                        for p in bottomPoints.reversed() { polygon.addLine(to: p) }
                        polygon.closeSubpath()

                        // Fill silhouette
                        context.fill(polygon, with: .color(lineColor.opacity(0.35)))

                        // Outline
                        var outline = Path()
                        outline.move(to: first)
                        for p in topPoints.dropFirst() { outline.addLine(to: p) }
                        for p in bottomPoints.reversed() { outline.addLine(to: p) }
                        outline.closeSubpath()
                        context.stroke(outline, with: .color(lineColor.opacity(0.9)), lineWidth: 1)
                    }
                }
            }
        }
        .accessibilityLabel("Waveform")
    }
}
