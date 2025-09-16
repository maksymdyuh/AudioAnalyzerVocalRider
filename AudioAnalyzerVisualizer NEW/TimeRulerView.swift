import SwiftUI

struct TimeRulerView: View {
    let duration: Double

    private func marks() -> [Double] {
        guard duration > 0 else { return [] }
        // Choose step by duration
        let step: Double
        switch duration {
        case 0..<10: step = 0.5
        case 10..<30: step = 1
        case 30..<90: step = 5
        case 90..<300: step = 10
        default: step = 30
        }
        var xs: [Double] = []
        var t: Double = 0
        while t <= duration + 0.0001 {
            xs.append(t)
            t += step
        }
        return xs
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let ms = marks()
            ZStack(alignment: .topLeading) {
                Rectangle().fill(Color.clear)
                ForEach(Array(ms.enumerated()), id: \.offset) { _, t in
                    let x = CGFloat(t / max(duration, 0.000001)) * w
                    Path { p in
                        p.move(to: CGPoint(x: x, y: 0))
                        p.addLine(to: CGPoint(x: x, y: h))
                    }
                    .stroke(Color.gray.opacity(0.25), lineWidth: 1)
                    Text(formatTime(t))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .position(x: min(max(20, x + 12), w - 20), y: h/2)
                }
            }
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        let s = Int(seconds.rounded())
        let m = s / 60
        let r = s % 60
        return String(format: "%02d:%02d", m, r)
    }
}
