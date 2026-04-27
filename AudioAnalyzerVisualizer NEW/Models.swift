//
//  Models.swift
//  AudioAnalyzerVisualizer NEW
//
//  Defines data models used by the analyzer and UI.
//

import Foundation

struct AnalysisResult: Codable, Equatable {
    let sampleRate: Double
    let duration: Double
    let averageRMSdB: Double
    let windowRMSdB: [Double]
    let windowMs: Int
    // Optional metadata (filled by backend or at runtime)
    var bitDepth: Int?
    var bitrateKbps: Int?
    var suggestedGain: [Double]? // Сюди ми зберігатимемо результат Vocal Rider
}
