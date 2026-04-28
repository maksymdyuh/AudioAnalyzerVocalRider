import Foundation
import AVFoundation

let start = Date()
let engine = AVAudioEngine()
let player = AVAudioPlayerNode()
engine.attach(player)
engine.connect(player, to: engine.mainMixerNode, format: nil)
try! engine.start()
let url = URL(fileURLWithPath: "dummy.wav") // 1 sec file
let readFile = try! AVAudioFile(forReading: url)

player.scheduleSegment(readFile, startingFrame: 0, frameCount: 22050, at: nil, completionCallbackType: .dataPlayedBack) { callbackType in
    print("callbackType \(callbackType.rawValue) at \(Date().timeIntervalSince(start))")
}
print("started play at \(Date().timeIntervalSince(start))")
player.play()
for _ in 0..<15 {
    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
}
