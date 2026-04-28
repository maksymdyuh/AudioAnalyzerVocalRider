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

player.scheduleSegment(readFile, startingFrame: 0, frameCount: 44100, at: nil) {
    print("completion block invoked after \(Date().timeIntervalSince(start)) seconds")
}

player.play()
RunLoop.main.run(until: Date(timeIntervalSinceNow: 1.0))
print("is playing at end: \(player.isPlaying)")
