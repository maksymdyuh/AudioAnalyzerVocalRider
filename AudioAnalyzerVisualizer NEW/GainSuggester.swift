//
//  GainSuggester.swift
//  AudioAnalyzerVisualizer NEW
//
//  Computes a recommended clip gain envelope (dB) to steer windowed RMS toward a target.
//  Implements a professional Vocal Rider algorithm with Gate Threshold, Attack, and Release.
//

import Foundation

enum GainSuggester {
    struct Params {
        var targetDB: Double = -18.0           // Target loudness in dBFS
        var thresholdDB: Double = -40.0        // Noise gate threshold: ignore audio below this
        var minGainDB: Double = -12.0          // Max attenuation (dB)
        var maxGainDB: Double = 12.0           // Max boost (dB)
        var attackMs: Double = 5.0             // Fast response when audio gets louder (fader down)
        var releaseMs: Double = 100.0          // Slow response when audio gets quieter (fader up)
        var windowMs: Double = 20.0            // Time elapsed per window element
        var lookaheadMs: Double = 15.0         // Anticipate transients before they happen
    }

    static func suggest(windowRMSdB: [Double], params: Params) -> [Double] {
        guard !windowRMSdB.isEmpty else { return [] }
        let p = params
        
        // Calculate smoothing coefficients for a one-pole lowpass filter
        // Formula for Alpha: exp(-dt / timeConstant)
        let dt = p.windowMs
        let alphaAttack = p.attackMs > 0 ? exp(-dt / p.attackMs) : 0.0
        let alphaRelease = p.releaseMs > 0 ? exp(-dt / p.releaseMs) : 0.0
        
        var envelope: [Double] = Array(repeating: 0.0, count: windowRMSdB.count)
        var currentGain = 0.0
        
        for i in 0..<windowRMSdB.count {
            let rms = windowRMSdB[i]
            var targetGain = 0.0
            
            // 1. Noise Gate Check: we only apply Rider to actual signal, not noise/breaths
            if rms > p.thresholdDB {
                targetGain = p.targetDB - rms
                targetGain = clamp(targetGain, p.minGainDB, p.maxGainDB)
            } else {
                // Return fader to 0 (unity gain) when audio is silent
                targetGain = 0.0
            }
            
            // 2. Apply Smoothing (Envelope Following the Gain)
            if targetGain < currentGain {
                // Fader moving down (Attack phase - acting fast to reduce loud transients)
                currentGain = alphaAttack * currentGain + (1.0 - alphaAttack) * targetGain
            } else {
                // Fader moving up (Release phase - acting slowly to boost quieter phrases gracefully)
                currentGain = alphaRelease * currentGain + (1.0 - alphaRelease) * targetGain
            }
            
            envelope[i] = currentGain
        }
        
        // 3. Apply Lookahead (Shift timing backward to catch peaks early)
        let shiftWindows = max(0, Int(round(p.lookaheadMs / p.windowMs)))
        if shiftWindows > 0 {
            var finalEnvelope = envelope
            for i in 0..<envelope.count {
                if i + shiftWindows < envelope.count {
                    finalEnvelope[i] = envelope[i + shiftWindows]
                } else {
                    finalEnvelope[i] = envelope.last ?? 0.0
                }
            }
            return finalEnvelope
        }
        
        return envelope
    }

    private static func clamp(_ x: Double, _ a: Double, _ b: Double) -> Double {
        return max(a, min(b, x))
    }
}
