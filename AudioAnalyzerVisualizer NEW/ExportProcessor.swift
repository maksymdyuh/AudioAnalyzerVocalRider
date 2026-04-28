import Foundation
import AVFoundation

class ExportProcessor {
    static func export(doc: AppModel.Doc, riderAmount: Double, to outputURL: URL, prefix: String, filename: String) {
        // Here we export the track
        let outputFilename = prefix + filename
        let ext = doc.url.pathExtension.isEmpty ? "wav" : doc.url.pathExtension
        let finalURL = outputURL.appendingPathComponent(outputFilename).appendingPathExtension(ext)
        print("Exporting \(doc.url.path) to \(finalURL.path)")
        
        let engine = AVAudioEngine()
        let playerNode = AVAudioPlayerNode()
        let mixerNode = AVAudioMixerNode()
        
        engine.attach(playerNode)
        engine.attach(mixerNode)
        
        engine.connect(playerNode, to: mixerNode, format: nil)
        engine.connect(mixerNode, to: engine.mainMixerNode, format: nil)
        
        guard let audioFile = try? AVAudioFile(forReading: doc.url) else { return }
        
        let totalFrames = AVAudioFrameCount(audioFile.length)
        let format = audioFile.processingFormat
        
        // Setup offline rendering
        let outFile: AVAudioFile
        do {
            outFile = try AVAudioFile(forWriting: finalURL, settings: format.settings, commonFormat: format.commonFormat, interleaved: format.isInterleaved)
        } catch {
            print("Failed to start writing file to \(finalURL.path): \(error)")
            return
        }
            
        let maxFrames: AVAudioFrameCount = 4096
            try? engine.enableManualRenderingMode(.offline, format: format, maximumFrameCount: maxFrames)
        
        try? engine.start()
        playerNode.scheduleFile(audioFile, at: nil, completionHandler: nil)
        playerNode.play()
        
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: engine.manualRenderingMaximumFrameCount) else { return }
        
        guard let gainEnv = doc.result?.suggestedGain, !gainEnv.isEmpty else { return }
        let winDuration = Double(doc.result?.windowMs ?? 20) / 1000.0
        
        var renderedFrames: AVAudioFramePosition = 0
        
        while engine.manualRenderingSampleTime < audioFile.length {
            let framesToRender = min(maxFrames, AVAudioFrameCount(audioFile.length - engine.manualRenderingSampleTime))
            
            // Update gain based on current time
            let fileTime = Double(engine.manualRenderingSampleTime) / format.sampleRate
            let exactIndex = fileTime / winDuration
            let index1 = Int(floor(exactIndex))
            let index2 = index1 + 1
            let fraction = exactIndex - Double(index1)
            
            var interpolatedDb: Double = 0.0
            if index1 >= 0 && index2 < gainEnv.count {
                interpolatedDb = gainEnv[Int(index1)] + (gainEnv[Int(index2)] - gainEnv[Int(index1)]) * fraction
            } else if index1 >= 0 && index1 < gainEnv.count {
                interpolatedDb = gainEnv[Int(index1)]
            }
            
            let actualDb = interpolatedDb * riderAmount
            let linearGain = Float(pow(10.0, actualDb / 20.0))
            mixerNode.outputVolume = linearGain
            
            do {
                let status = try engine.renderOffline(framesToRender, to: buffer)
                if status == .success {
                    try outFile.write(from: buffer)
                    renderedFrames += AVAudioFramePosition(framesToRender)
                }
            } catch {
                break
            }
        }
        playerNode.stop()
        engine.stop()
    }
}
