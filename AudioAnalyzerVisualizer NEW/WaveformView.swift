//
//  WaveformView.swift
//  AudioAnalyzerVisualizer NEW
//
//  Renders a simple vertical-line waveform from dBFS samples with grid and center line.
//

import SwiftUI
import AVFoundation

struct WaveformView: View {
    let samplesDB: [Double] // negative dBFS values
    var suggestedGain: [Double]? = nil // Масив з Vocal Rider (-12..12 dB)
    var lineColor: Color = .accentColor
    var showGrid: Bool = true
    var amplitudeScale: CGFloat = 1.0 // visual vertical zoom
    var timeZoom: CGFloat = 1.0       // horizontal zoom factor (1 = full track)
    var timeStart: CGFloat = 0.0      // normalized left edge [0, 1 - 1/timeZoom]

    // For high-zoom true waveform rendering
    var duration: Double = 0
    var sampleRate: Double = 44100
    var audioURL: URL? = nil
    var hiResThresholdSec: Double = 0.15 // when visible window <= threshold, draw raw waveform

    @State private var viewWidth: CGFloat = 0
    @State private var hiResSamples: [Float] = []
    @State private var hiResWindow: (startTime: Double, duration: Double)? = nil
    @State private var hiResLoading = false

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

            let visibleDuration = Double(f) * max(duration, 0.0)
            let shouldDrawHiRes = (audioURL != nil && visibleDuration > 0 && visibleDuration <= hiResThresholdSec && w > 0)

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

                // If very high zoom and we have hi-res samples for the current window, draw polyline of the waveform
                if shouldDrawHiRes, let win = hiResWindow, !hiResSamples.isEmpty,
                   abs(win.startTime - (Double(startNorm) * duration)) < 1e-3 && abs(win.duration - visibleDuration) < 1e-3 {
                    let count = hiResSamples.count
                    if count > 1 {
                        var path = Path()
                        let halfH = h / 2.0
                        let scaleY = halfH
                        for i in 0..<count {
                            let x = CGFloat(i) / CGFloat(count - 1) * w
                            let y = halfH - CGFloat(hiResSamples[i]) * amplitudeScale * scaleY
                            if i == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
                        }
                        context.stroke(path, with: .color(lineColor.opacity(0.98)), style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))
                    }
                } else {
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
                
                // --- ДРУКИЙ КРОК: Малюємо лінію Vocal Rider (Gain Envelope) поверх хвилі ---
                if let env = suggestedGain, !env.isEmpty, iStart < iEnd {
                    var gainPath = Path()
                    var hasMoved = false
                    
                    let maxGainVisual: Double = 12.0 // +/- 12 dB для візуалізації
                    
                    for i in iStart..<iEnd {
                        guard i < env.count else { break }
                        let gainValue = env[i] // від -12 до 12 (або більше/менше)
                        
                        // Нормалізуємо значення так, щоб 0 dB було рівно по центру
                        // +12 dB буде вгорі (0), -12 dB буде внизу (h)
                        let clampedGain = max(-maxGainVisual, min(maxGainVisual, gainValue))
                        // Значення від -1.0 до 1.0 (-1 це низ, 1 це верх)
                        let normalizedGain = CGFloat(clampedGain / maxGainVisual)
                        
                        let y = (h / 2.0) - (normalizedGain * (h / 2.0))
                        
                        let denom = max(CGFloat(visibleCount - 1), 1)
                        let xf = (CGFloat(i - iStart) / denom) * max(w - 1, 1)
                        let x = CGFloat(max(0, min(Int(w - 1), Int(xf))))
                        
                        if !hasMoved {
                            gainPath.move(to: CGPoint(x: x, y: y))
                            hasMoved = true
                        } else {
                            gainPath.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                    
                    if hasMoved {
                        // Малюємо лінію гучності (наприклад, яскраво-жовтого кольору)
                        context.stroke(gainPath, with: .color(.yellow), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    }
                }
            }
            .background(
                Color.clear
                    .onAppear {
                        viewWidth = w
                        requestHiResIfNeeded(width: w, visibleDuration: visibleDuration, startNorm: startNorm)
                    }
                    .onChange(of: geo.size.width) { newW in
                        viewWidth = newW
                        requestHiResIfNeeded(width: newW, visibleDuration: visibleDuration, startNorm: startNorm)
                    }
                    .onChange(of: timeZoom) { _ in
                        requestHiResIfNeeded(width: w, visibleDuration: visibleDuration, startNorm: startNorm)
                    }
                    .onChange(of: timeStart) { _ in
                        requestHiResIfNeeded(width: w, visibleDuration: visibleDuration, startNorm: startNorm)
                    }
            )
        }
        .accessibilityLabel("Waveform")
    }

    private func requestHiResIfNeeded(width: CGFloat, visibleDuration: Double, startNorm: CGFloat) {
        guard let url = audioURL, visibleDuration > 0, visibleDuration <= hiResThresholdSec, width > 0 else {
            // Clear if not in hi-res mode
            if !hiResSamples.isEmpty { hiResSamples = [] }
            hiResWindow = nil
            return
        }
        if hiResLoading { return }
        let startTimeSec = Double(startNorm) * duration
        // If we already have matching window, skip
        if let win = hiResWindow, abs(win.startTime - startTimeSec) < 1e-3 && abs(win.duration - visibleDuration) < 1e-3 {
            return
        }
        hiResLoading = true
        Task.detached(priority: .userInitiated) {
            let sr = max(1.0, sampleRate)
            let startFrame = max(Int64(startTimeSec * sr), 0)
            let framesToRead = max(Int64(visibleDuration * sr), 1)
            do {
                let file = try AVAudioFile(forReading: url)
                let fmt = file.processingFormat
                let channels = Int(fmt.channelCount)
                file.framePosition = startFrame
                let cap = AVAudioFrameCount(framesToRead)
                guard let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: cap) else {
                    await MainActor.run { self.hiResLoading = false }
                    return
                }
                try file.read(into: buf, frameCount: cap)
                let frames = Int(buf.frameLength)
                guard frames > 1, let data = buf.floatChannelData else {
                    await MainActor.run { self.hiResLoading = false }
                    return
                }
                // Mixdown to mono
                var mono = Array(repeating: Float(0), count: frames)
                for ch in 0..<channels {
                    let ptr = data[ch]
                    for i in 0..<frames { mono[i] += ptr[i] }
                }
                if channels > 0 {
                    let inv = 1.0 / Float(channels)
                    for i in 0..<frames { mono[i] *= inv }
                }
                // Resample to at least 2 samples per pixel with linear interpolation (for a smooth line)
                let targetPts = min(frames, max(4, Int(width) * 2))
                var samplesOut: [Float] = Array(repeating: 0, count: targetPts)
                if frames <= targetPts {
                    // Pad/trim to target
                    for i in 0..<targetPts { samplesOut[i] = mono[min(i, frames - 1)] }
                } else {
                    let step = Double(frames - 1) / Double(targetPts - 1)
                    for k in 0..<targetPts {
                        let pos = Double(k) * step
                        let i0 = Int(pos.rounded(.down))
                        let i1 = min(frames - 1, i0 + 1)
                        let frac = Float(pos - Double(i0))
                        let v0 = mono[i0]
                        let v1 = mono[i1]
                        samplesOut[k] = v0 + (v1 - v0) * frac
                    }
                }
                await MainActor.run {
                    self.hiResSamples = samplesOut
                    self.hiResWindow = (startTime: startTimeSec, duration: visibleDuration)
                    self.hiResLoading = false
                }
            } catch {
                await MainActor.run {
                    self.hiResSamples = []
                    self.hiResWindow = nil
                    self.hiResLoading = false
                }
            }
        }
    }
}
