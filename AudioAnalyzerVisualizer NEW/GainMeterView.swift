import SwiftUI

struct GainMeterView: View {
    let currentDB: Double?
    let peakHoldDB: Double?

    private let minDB: Double = -30
    private let maxDB: Double = 0

    private func y(for db: Double, height: CGFloat) -> CGFloat {
        let clamped = max(minDB, min(maxDB, db))
        let t = (clamped - minDB) / (maxDB - minDB) // 0..1
        return height * CGFloat(1 - t)
    }

    var body: some View {
        GeometryReader { geo in
            let h = geo.size.height
            let w = geo.size.width
            let corner: CGFloat = 6
            ZStack {
                // Background with subtle glass effect
                RoundedRectangle(cornerRadius: corner)
                    .fill(
                        LinearGradient(colors: [Color.black.opacity(0.25), Color.black.opacity(0.05)], startPoint: .bottom, endPoint: .top)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: corner)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.25), radius: 3, x: 0, y: 1)

                // Gradient fill up to current level
                if let v = currentDB {
                    let yVal = y(for: v, height: h)
                    VStack(spacing: 0) {
                        Spacer(minLength: yVal)
                        LinearGradient(colors: [Color.green, Color.yellow, Color.red], startPoint: .bottom, endPoint: .top)
                            .mask(
                                RoundedRectangle(cornerRadius: corner)
                                    .padding(.horizontal, 2)
                            )
                            .frame(height: h - yVal)
                    }
                }

                // Peak hold line
                if let peak = peakHoldDB {
                    let yPeak = y(for: peak, height: h)
                    Rectangle()
                        .fill(Color.white.opacity(0.9))
                        .frame(width: w - 4, height: 2)
                        .position(x: w/2, y: yPeak)
                }

                // Tick marks on the left edge only, with subtle labels
                VStack(spacing: 0) {
                    ForEach([0, -3, -6, -9, -12, -18, -24, -30], id: \.self) { mark in
                        let yMark = y(for: Double(mark), height: h)
                        Rectangle()
                            .fill(Color.white.opacity(mark % -6 == 0 ? 0.35 : 0.2))
                            .frame(width: mark % -6 == 0 ? 10 : 6, height: 1)
                            .position(x: 6, y: yMark)
                        Text("\(mark)")
                            .font(.system(size: 8, weight: .regular, design: .monospaced))
                            .foregroundColor(.white.opacity(0.55))
                            .position(x: 20, y: yMark - 7)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }
}
