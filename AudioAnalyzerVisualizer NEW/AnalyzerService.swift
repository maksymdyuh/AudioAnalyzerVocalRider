//
//  AnalyzerService.swift
//  AudioAnalyzerVisualizer NEW
//
//  Provides audio analysis via Swift (AVFoundation) with optional Python backend
//  executed as a separate process (no PythonKit).
//

import Foundation
import AVFoundation

enum AnalyzerError: Error, LocalizedError {
    case cannotRead
    case invalidAudio
    case pythonFailed(String)
    case scriptNotConfigured

    var errorDescription: String? {
        switch self {
        case .cannotRead: return "Cannot read audio file."
        case .invalidAudio: return "Unsupported or invalid audio format."
        case .pythonFailed(let msg): return "Python analyzer failed: \(msg)"
        case .scriptNotConfigured: return "Python analyzer script is not configured. Set AAV_PY_ANALYZER env var to the analyzer.py path."
        }
    }
}

final class AnalyzerService {

    static func analyze(url: URL, preferPython: Bool = true, windowMs: Int = 20) async throws -> AnalysisResult {
        if preferPython, PythonAnalyzer.isConfigured {
            return try await PythonAnalyzer.analyze(url: url, windowMs: windowMs)
        } else {
            return try await SwiftAnalyzer.analyze(url: url, windowMs: windowMs)
        }
    }

    private final class SwiftAnalyzer {
        static func analyze(url: URL, windowMs: Int) async throws -> AnalysisResult {
            let file = try AVAudioFile(forReading: url)
            let format = file.processingFormat
            let frameCount = AVAudioFrameCount(file.length)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
                throw AnalyzerError.cannotRead
            }
            try file.read(into: buffer, frameCount: frameCount)
            let sr = format.sampleRate
            let channels = Int(format.channelCount)
            let totalFrames = Int(buffer.frameLength)
            guard let channelData = buffer.floatChannelData else { throw AnalyzerError.cannotRead }

            var mono = [Float](repeating: 0, count: totalFrames)
            for i in 0..<totalFrames {
                var sum: Float = 0
                for c in 0..<channels { sum += channelData[c][i] }
                mono[i] = sum / Float(max(channels, 1))
            }

            let windowFrames = max(1, Int(sr * Double(windowMs) / 1000.0))
            var windowRMSdB = [Double]()
            windowRMSdB.reserveCapacity(totalFrames / windowFrames + 1)

            var i = 0
            var sumsq: Double = 0
            var count = 0
            var globalSumsq: Double = 0

            while i < totalFrames {
                let x = Double(mono[i])
                sumsq += x * x
                globalSumsq += x * x
                count += 1
                if count == windowFrames {
                    let rms = sqrt(sumsq / Double(count))
                    let db = 20.0 * log10(max(rms, 1e-12))
                    windowRMSdB.append(db)
                    sumsq = 0
                    count = 0
                }
                i += 1
            }
            if count > 0 { // tail window
                let rms = sqrt(sumsq / Double(count))
                let db = 20.0 * log10(max(rms, 1e-12))
                windowRMSdB.append(db)
            }

            let globalRMS = sqrt(globalSumsq / Double(totalFrames))
            let avgDb = 20.0 * log10(max(globalRMS, 1e-12))

            return AnalysisResult(
                sampleRate: sr,
                duration: Double(totalFrames) / sr,
                averageRMSdB: avgDb,
                windowRMSdB: windowRMSdB,
                windowMs: windowMs
            )
        }
    }

    private final class PythonAnalyzer {
        static var scriptURL: URL? {
            if let path = ProcessInfo.processInfo.environment["AAV_PY_ANALYZER"], !path.isEmpty {
                return URL(fileURLWithPath: path)
            }
            return nil
        }
        static var isConfigured: Bool {
            guard let url = scriptURL else { return false }
            return FileManager.default.fileExists(atPath: url.path)
        }

        static func analyze(url: URL, windowMs: Int) async throws -> AnalysisResult {
            guard let script = scriptURL else { throw AnalyzerError.scriptNotConfigured }
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            proc.arguments = ["python3", script.path, url.path, "--window-ms", "\(windowMs)"]

            let out = Pipe()
            let err = Pipe()
            proc.standardOutput = out
            proc.standardError = err

            try proc.run()
            proc.waitUntilExit()

            let data = out.fileHandleForReading.readDataToEndOfFile()
            let errData = err.fileHandleForReading.readDataToEndOfFile()
            if proc.terminationStatus != 0 {
                let msg = String(data: errData, encoding: .utf8) ?? "Unknown error"
                throw AnalyzerError.pythonFailed(msg.trimmingCharacters(in: .whitespacesAndNewlines))
            }
            let decoder = JSONDecoder()
            return try decoder.decode(AnalysisResult.self, from: data)
        }
    }
}
