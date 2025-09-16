//
//  GainSuggester.swift
//  AudioAnalyzerVisualizer NEW
//
//  Computes a recommended clip gain envelope (dB) to steer windowed RMS toward a target.
//

import Foundation

enum GainSuggester {
    struct Params {
        var targetDB: Double = -18.0         // target loudness in dBFS
        var minGainDB: Double = -12.0        // min allowed gain adjustment per window (dB)
        var maxGainDB: Double = 12.0         // max allowed gain adjustment per window (dB)
        var maxStepDB: Double = 1.0          // max change between adjacent windows (dB per window)
        var smoothWindow: Int = 3            // moving average window (odd recommended)
    }

    static func suggest(windowRMSdB: [Double], params: Params) -> [Double] {
        guard !windowRMSdB.isEmpty else { return [] }
        let p = params
        // Initial desired gain to hit target per window
        let desired = windowRMSdB.map { clamp(p.targetDB - $0, p.minGainDB, p.maxGainDB) }
        // Step-limit (slew) the gain to avoid abrupt changes
        var stepped: [Double] = Array(repeating: 0, count: desired.count)
        var prev = 0.0
        for i in 0..<desired.count {
            let aim = desired[i]
            let delta = clamp(aim - prev, -p.maxStepDB, p.maxStepDB)
            let next = prev + delta
            stepped[i] = clamp(next, p.minGainDB, p.maxGainDB)
            prev = stepped[i]
        }
        // Optional moving-average smoothing
        let k = max(1, p.smoothWindow)
        if k <= 1 { return stepped }
        return movingAverage(stepped, k)
    }

    private static func clamp(_ x: Double, _ a: Double, _ b: Double) -> Double {
        return max(a, min(b, x))
    }

    private static func movingAverage(_ x: [Double], _ w: Int) -> [Double] {
        guard w > 1, !x.isEmpty else { return x }
        var out = Array(repeating: 0.0, count: x.count)
        var sum = 0.0
        var q: [Double] = []
        q.reserveCapacity(w)
        for i in 0..<x.count {
            sum += x[i]
            q.append(x[i])
            if q.count > w {
                sum -= q.removeFirst()
            }
            out[i] = sum / Double(q.count)
        }
        return out
    }
}
