import Foundation
import AVFoundation

let start = Date()
let engine = AVAudioEngine()
let player = AVAudioPlayerNode()
engine.attach(player)
engine.connect(player, to: engine.mainMixerNode, format: nil)
try! engine.start()
let url = URL(fileURLWithPath: "dummy.wav") // 1 sec file (44100 frames)
let readFile = try! AVAudioFile(forReading: url)

player.scheduleSegment(readFile, startingFrame: 0, frameCount: 44100, at: nil, completionCallbackType: .dataPlayedBack) { callbackType in
    print("callbackType \(callbackType.rawValue) at \(Date().timeIntervalSince(start))")
}
print("started play at \(Date().timeIntervalSince(start))")
player.play()
for _ in 0..<12 {
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
    print("player.isPlaying = \(player.isPlaying)")
}
