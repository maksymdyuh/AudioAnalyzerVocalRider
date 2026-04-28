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
    private var playbackTimer: Timer?
    
    // Стан Vocal Rider
    var suggestedGain: [Double]?
    var windowMs: Double = 20.0
    var riderAmount: Double = 0.0
    
    // Щоб уникати хибних зупинок при перемотуванні (seek)
    private var playSessionID = UUID()
    
    // Щоб знати точний час програвання
    private var baseTime: Double = 0.0
    private var playbackStartDate: Date?
    
    init() {
        engine.attach(playerNode)
        engine.attach(mixerNode)
        
        // З'єднуємо вузли (player -> mixer -> main out)
        engine.connect(playerNode, to: mixerNode, format: nil)
        engine.connect(mixerNode, to: engine.mainMixerNode, format: nil)
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
        
        if totalFrames > startFrame {
            let framesCount = AVAudioFrameCount(totalFrames - startFrame)
            playerNode.stop()
            let currentSessionId = UUID()
            self.playSessionID = currentSessionId
            
            // Плануємо шматок файлу
            playerNode.scheduleSegment(file, startingFrame: startFrame, frameCount: framesCount, at: nil)
            baseTime = time
            playbackStartDate = Date()
            playerNode.play()
            self.currentTime = time
            isPlaying = true
            startTimer()
        }
    }
    
    func pause() {
        playerNode.pause()
        isPlaying = false
        stopTimer()
    }
    
    func stop() {
        playerNode.stop()
        isPlaying = false
        stopTimer()
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
    
    private func startTimer() {
        stopTimer()
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { [weak self] _ in
                self?.updateRealtime()
            }
            RunLoop.main.add(self.playbackTimer!, forMode: .common)
            self.playbackTimer?.fire()
        }
    }
    
    private func stopTimer() {
        playbackTimer?.invalidate()
        playbackTimer = nil
    }
    
    // 🎚️ Магія Vocal Rider, що крутить "ручку гучності" кожну мілісекунду
    private func updateRealtime() {
        
        guard let startDate = playbackStartDate, playerNode.isPlaying else { return }
        
        let elapsed = Date().timeIntervalSince(startDate)
        let fileTime = max(0.0, baseTime + elapsed)
        
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