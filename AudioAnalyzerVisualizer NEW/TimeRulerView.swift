import SwiftUI

struct TimeRulerView: View {
    let duration: Double
    var timeZoom: CGFloat = 1.0
    var timeStart: CGFloat = 0.0

    private func majorStep(for visible: Double) -> Double {
        // Base step based on visible seconds
        switch visible {
        case 0..<2: return 0.1
        case 2..<5: return 0.25
        case 5..<10: return 0.5
        case 10..<30: return 1
        case 30..<90: return 5
        case 90..<300: return 10
        case 300..<900: return 30
        default: return 60
        }
    }

    private func marks(width: CGFloat) -> (major: [Double], minor: [Double]) {
        guard duration > 0, width > 0 else { return ([], []) }
        let f = max(1.0 / max(timeZoom, 0.000001), 0.000001)
        let visStart = max(0.0, Double(timeStart) * duration)
        let visDur = max(0.0, Double(f) * duration)
        let step = majorStep(for: visDur)
        // pick minor as 1/5 of major, but avoid too dense
        let minorStep = max(step / 5.0, 0.05)

        var major: [Double] = []
        var minor: [Double] = []

        let firstMajor = (floor(visStart / step)) * step
        var t = firstMajor
        let end = visStart + visDur
        while t <= end + 0.0001 {
            major.append(max(0, min(duration, t)))
            // insert minor ticks between t..t+step
            var m = t + minorStep
            while m < t + step - 1e-6 {
                if m >= visStart - 1e-6 && m <= end + 1e-6 {
                    minor.append(max(0, min(duration, m)))
                }
                m += minorStep
            }
            t += step
        }
        return (major, minor)
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let f = max(1.0 / max(timeZoom, 0.000001), 0.000001)
            let ticks = marks(width: w)
            ZStack(alignment: .topLeading) {
                Rectangle().fill(Color.clear)
                // Minor ticks
                ForEach(Array(ticks.minor.enumerated()), id: \.offset) { _, t in
                    let norm = CGFloat(t / max(duration, 0.000001))
                    let rel = (norm - timeStart) / f
                    let x = rel * w
                    if x >= -20 && x <= w + 20 {
                        Path { p in
                            p.move(to: CGPoint(x: x, y: h * 0.35))
                            p.addLine(to: CGPoint(x: x, y: h))
                        }
                        .stroke(Color.gray.opacity(0.18), lineWidth: 1)
                    }
                }
                // Major ticks + labels
                ForEach(Array(ticks.major.enumerated()), id: \.offset) { _, t in
                    let norm = CGFloat(t / max(duration, 0.000001))
                    let rel = (norm - timeStart) / f
                    let x = rel * w
                    if x >= -40 && x <= w + 40 {
                        Path { p in
                            p.move(to: CGPoint(x: x, y: 0))
                            p.addLine(to: CGPoint(x: x, y: h))
                        }
                        .stroke(Color.gray.opacity(0.28), lineWidth: 1)
                        Text(smartFormatTime(t))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .position(x: min(max(24, x + 12), w - 24), y: h * 0.25)
                    }
                }
            }
        }
    }

    private func smartFormatTime(_ seconds: Double) -> String {
        if seconds < 60 {
            if seconds < 1 { return String(format: "%.2fs", seconds) }
            if seconds < 10 { return String(format: "%.1fs", seconds) }
            return String(format: "%.0fs", seconds)
        }
        let s = Int(seconds.rounded())
        let m = s / 60
        let r = s % 60
        return String(format: "%d:%02d", m, r)
    }
}
