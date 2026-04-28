import Foundation
import AVFoundation

let engine = AVAudioEngine()
let player = AVAudioPlayerNode()
engine.attach(player)
engine.connect(player, to: engine.mainMixerNode, format: nil)
try! engine.start()
let url = URL(fileURLWithPath: "dummy.wav")
let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
let file = try! AVAudioFile(forWriting: url, settings: format.settings)
let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 44100)!
buffer.frameLength = 44100
try! file.write(from: buffer)
let readFile = try! AVAudioFile(forReading: url)

player.scheduleSegment(readFile, startingFrame: 0, frameCount: 44100, at: nil, completionHandler: nil)
player.play()

for _ in 0..<10 {
    Thread.sleep(forTimeInterval: 0.1)
    if let nodeTime = player.lastRenderTime, let playerTime = player.playerTime(forNodeTime: nodeTime) {
        print("isPlaying=\(player.isPlaying) sampleTime=\(playerTime.sampleTime)")
    } else {
        print("time is nil")
    }
}
