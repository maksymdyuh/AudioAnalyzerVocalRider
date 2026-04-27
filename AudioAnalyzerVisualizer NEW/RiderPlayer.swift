import Foundation
import AVFoundation
import Combine
import CoreVideo

class RiderPlayer: ObservableObject {
    static let shared = RiderPlayer()
    
    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    // Використовуємо Mixer для керування гучністю. Mixer відмінно створює підсилення понад 1.0 (gain)
    private let mixerNode = AVAudioMixerNode()
    
    @Published var isPlaying = false
    @Published var currentTime: Double = 0.0
    var url: URL?
    
    private var audioFile: AVAudioFile?
    private var displayLink: CVDisplayLink?
    
    // Стан Vocal Rider
    var suggestedGain: [Double]?
    var windowMs: Double = 20.0
    var riderAmount: Double = 0.0
    
    // Щоб знати точний час програвання
    private var baseTime: Double = 0.0
    
    init() {
        engine.attach(playerNode)
        engine.attach(mixerNode)
        
        // З'єднуємо вузли (player -> mixer -> main out)
        engine.connect(playerNode, to: mixerNode, format: nil)
        engine.connect(mixerNode, to: engine.mainMixerNode, format: nil)
        
        setupDisplayLink()
    }
    
    func load(url: URL) {
        stop()
        self.url = url
        do {
            audioFile = try AVAudioFile(forReading: url)
            mixerNode.outputVolume = 1.0 // Скидаємо гучність
        } catch {
            print("Failed to load audio: \(error)")
        }
    }
    
    func prepareToPlay() {
        if !engine.isRunning { try? engine.start() }
    }
    
    func play(from time: Double) {
        guard let file = audioFile else { return }
        
        if !engine.isRunning { try? engine.start() }
        
        let sampleRate = file.processingFormat.sampleRate
        let startFrame = AVAudioFramePosition(max(0, time) * sampleRate)
        let totalFrames = AVAudioFramePosition(file.length)
        let framesCount = AVAudioFrameCount(totalFrames - startFrame)
        
        if framesCount > 0 {
            playerNode.stop()
            // Плануємо шматок файлу
            playerNode.scheduleSegment(file, startingFrame: startFrame, frameCount: framesCount, at: nil) {
                // Викликається після завершення
                DispatchQueue.main.async { [weak self] in
                    self?.isPlaying = false
                    self?.pauseDisplayLink()
                }
            }
            baseTime = time
            playerNode.play()
            self.currentTime = time
            isPlaying = true
            resumeDisplayLink()
        }
    }
    
    func pause() {
        playerNode.pause()
        isPlaying = false
        pauseDisplayLink()
    }
    
    func stop() {
        playerNode.stop()
        isPlaying = false
        pauseDisplayLink()
        currentTime = 0.0
    }
    
    func seek(to time: Double) {
        let wasPlaying = isPlaying
        stop() // Необхідно, щоб очистити заплановані буфери
        currentTime = max(0, time)
        if wasPlaying {
            play(from: currentTime)
        }
    }
    
    private func setupDisplayLink() {
        CVDisplayLinkCreateWithActiveCGDisplays(&displayLink)
        if let dl = displayLink {
            let context = Unmanaged.passUnretained(self).toOpaque()
            // Цей колбек викликається синхронно з частотою монітору (зазвичай 60 FPS)
            CVDisplayLinkSetOutputCallback(dl, { (_, _, _, _, _, context) -> CVReturn in
                if let ctx = context {
                    let player = Unmanaged<RiderPlayer>.fromOpaque(ctx).takeUnretainedValue()
                    player.updateRealtime()
                }
                return kCVReturnSuccess
            }, context)
        }
    }
    
    private func resumeDisplayLink() {
        if let dl = displayLink { CVDisplayLinkStart(dl) }
    }
    
    private func pauseDisplayLink() {
        if let dl = displayLink { CVDisplayLinkStop(dl) }
    }
    
    // 🎚️ Магія Vocal Rider, що крутить "ручку гучності" кожну мілісекунду
    private func updateRealtime() {
        guard let nodeTime = playerNode.lastRenderTime, playerNode.isPlaying else { return }
        guard let playerTime = playerNode.playerTime(forNodeTime: nodeTime) else { return }
        
        let sampleRate = playerTime.sampleRate
        let fileTime = baseTime + Double(playerTime.sampleTime) / sampleRate
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.currentTime = fileTime
        }
        
        // Обчислення нового Gain (гучності) на основі нашої кривої Vocal Rider
        if let gainEnv = suggestedGain, !gainEnv.isEmpty {
            let winDuration = windowMs / 1000.0
            
            let exactIndex = fileTime / winDuration
            let index1 = Int(floor(exactIndex))
            let index2 = index1 + 1
            let fraction = exactIndex - Double(index1) // Для плавності
            
            var interpolatedDb: Double = 0.0
            if index1 >= 0 && index2 < gainEnv.count {
                // Лінійна інтерполяція між двома віконцями (щоб звук не стрибав як сходинки)
                let db1 = gainEnv[index1]
                let db2 = gainEnv[index2]
                interpolatedDb = db1 + (db2 - db1) * fraction
            } else if index1 >= 0 && index1 < gainEnv.count {
                interpolatedDb = gainEnv[index1]
            }
            
            // На скільки сильно впливає наш алгоритм (0..1)
            let actualDb = interpolatedDb * riderAmount
            
            // Децибели в Amplitude Scale (1.0 = норма, 2.0 = удвічі гучніше і т.д.)
            let linearGain = Float(pow(10.0, actualDb / 20.0))
            
            // Застосовуємо до мікшера!
            mixerNode.outputVolume = linearGain
        } else {
            mixerNode.outputVolume = 1.0
        }
    }
}