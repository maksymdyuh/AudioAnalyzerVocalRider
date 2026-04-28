import Foundation
import AVFoundation

let start = Date()
let engine = AVAudioEngine()
let player = AVAudioPlayerNode()
engine.attach(player)
engine.connect(player, to: engine.mainMixerNode, format: nil)
try! engine.start()
let url = URL(fileURLWithPath: "dummy.wav")
let readFile = try! AVAudioFile(forReading: url)

player.scheduleSegment(readFile, startingFrame: 0, frameCount: 22050, at: nil) // 0.5s

player.play()
for _ in 0..<10 {
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
    print("player.isPlaying = \(player.isPlaying)")
}
