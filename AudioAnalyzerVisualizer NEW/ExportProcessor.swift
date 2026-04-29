import Foundation
import AVFoundation

class ExportProcessor {
    static func export(doc: AppModel.Doc, riderAmount: Double, to outputURL: URL, prefix: String, filename: String) {
        // Here we export the track
        let outputFilename = prefix + filename
        let ext = doc.url.pathExtension.isEmpty ? "wav" : doc.url.pathExtension
        let finalURL = outputURL.appendingPathComponent(outputFilename).appendingPathExtension(ext)
        print("Exporting \(doc.url.path) to \(finalURL.path)")
        
        guard let audioFile = try? AVAudioFile(forReading: doc.url) else { return }
        
        let format = audioFile.processingFormat
        
        // Setup output file
        let outFile: AVAudioFile
        do {
            outFile = try AVAudioFile(forWriting: finalURL, settings: format.settings, commonFormat: format.commonFormat, interleaved: format.isInterleaved)
        } catch {
            print("Failed to start writing file to \(finalURL.path): \(error)")
            return
        }
            
        let maxFrames: AVAudioFrameCount = 8192
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: maxFrames) else { return }
        
        guard let gainEnv = doc.result?.suggestedGain, !gainEnv.isEmpty else { return }
        let winDuration = Double(doc.result?.windowMs ?? 20) / 1000.0
        let sampleRate = format.sampleRate
        let channelCount = Int(format.channelCount)
        
        var currentFramePosition: AVAudioFramePosition = 0
        
        while currentFramePosition < audioFile.length {
            let framesToRead = min(maxFrames, AVAudioFrameCount(audioFile.length - currentFramePosition))
            
            do {
                try audioFile.read(into: buffer, frameCount: framesToRead)
                
                // Sample-level continuous smoothing processing instead of 90ms blocks
                if let floatChannelData = buffer.floatChannelData {
                    for frame in 0..<Int(buffer.frameLength) {
                        let samplePosition = currentFramePosition + AVAudioFramePosition(frame)
                        let fileTime = Double(samplePosition) / sampleRate
                        
                        let exactIndex = fileTime / winDuration
                        let index1 = Int(floor(exactIndex))
                        let index2 = index1 + 1
                        let fraction = exactIndex - Double(index1)
                        
                        var interpolatedDb: Double = 0.0
                        if index1 >= 0 && index2 < gainEnv.count {
                            interpolatedDb = gainEnv[index1] + (gainEnv[index2] - gainEnv[index1]) * fraction
                        } else if index1 >= 0 && index1 < gainEnv.count {
                            interpolatedDb = gainEnv[index1]
                        }
                        
                        let actualDb = interpolatedDb * riderAmount
                        let linearGain = Float(pow(10.0, actualDb / 20.0))
                        
                        for channel in 0..<channelCount {
                            floatChannelData[channel][frame] *= linearGain
                        }
                    }
                }
                
                try outFile.write(from: buffer)
                currentFramePosition += AVAudioFramePosition(buffer.frameLength)
            } catch {
                print("Error processing audio: \(error)")
                break
            }
        }
        print("Export completed for \(finalURL.path)")
    }
}
