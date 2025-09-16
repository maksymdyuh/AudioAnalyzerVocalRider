//
//  ContentView.swift
//  AudioAnalyzerVisualizer NEW
//
//  Created by Максим Дюг on 16.09.2025.
//

import SwiftUI
import Combine
import AVFoundation
#if os(macOS)
import AppKit
import UniformTypeIdentifiers
#endif

struct ContentView: View {
    @EnvironmentObject var model: AppModel
    #if os(macOS)
    @State private var isDropTarget: Bool = false
    @State private var keyMonitor: Any?
    #endif

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {

            if model.docs.contains(where: { $0.isAnalyzing }) {
                HStack { ProgressView(); Text("Аналізую…") }.padding(.vertical, 4)
            }

            if !model.docs.isEmpty {
                TabView(selection: $model.selectedDocID) {
                    ForEach(model.docs, id: \.id) { doc in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text(doc.url.lastPathComponent)
                                    .font(.headline)
                                Spacer()
                                // Close tab button
                                Button(role: .destructive) {
                                    model.closeDoc(id: doc.id)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                }
                                .buttonStyle(.plain)
                                .help("Закрити вкладку")
                            }
                            if let res = doc.result {
                                GroupBox {
                                    VStack(alignment: .leading, spacing: 10) {
                                        Text(String(format: "avg level: %.1f dBFS", res.averageRMSdB))
                                            .font(.headline)
                                        Text(metaLine(result: res, url: doc.url))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        // Time ruler and current/total time
                                        TimeRulerView(duration: res.duration)
                                            .frame(height: 20)

                                        ZStack {
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(LinearGradient(colors: [Color.black.opacity(0.03), Color.black.opacity(0.06)], startPoint: .top, endPoint: .bottom))
                                            HStack(spacing: 6) {
                                                WaveformView(samplesDB: res.windowRMSdB, lineColor: .accentColor, showGrid: true, amplitudeScale: amplitudeScale)
                                                    .padding(.vertical, 8)
                                                    .padding(.horizontal, 4)
                                                    .overlay(
                                                        GeometryReader { geo in
                                                            ZStack(alignment: .topLeading) {
                                                                let x = max(0, min(geo.size.width, geo.size.width * playheadProgress))
                                                                Path { p in
                                                                    p.move(to: CGPoint(x: x, y: 0))
                                                                    p.addLine(to: CGPoint(x: x, y: geo.size.height))
                                                                }
                                                                .stroke(Color.white, lineWidth: 1.5)

                                                                Color.clear
                                                                    .contentShape(Rectangle())
                                                                    .gesture(DragGesture(minimumDistance: 0).onEnded { v in
                                                                        let localX = max(0, min(v.location.x, geo.size.width))
                                                                        let progress = localX / max(geo.size.width, 0.000001)
                                                                        playheadProgress = progress
                                                                        audioPlayer?.currentTime = res.duration * progress
                                                                    })
                                                            }
                                                        }
                                                    )
                                                // Vertical zoom slider (same height as meter)
                                                VStack {
                                                    Slider(value: $amplitudeScale, in: 0.5...5.0)
                                                        .rotationEffect(.degrees(-90))
                                                        .frame(height: meterHeight)
                                                        .scaleEffect(1.4)
                                                        .padding(.horizontal, 4)
                                                }
                                                .frame(width: 56)

                                                GainMeterView(currentDB: currentDB(res: res), peakHoldDB: peakHoldDB)
                                                    .frame(width: 26, height: meterHeight)
                                            }
                                        }
                                        .overlay(alignment: .topLeading) {
                                            Text("\(formatTime(seconds: currentTime(res: res)))/\(formatTime(seconds: res.duration))")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .padding(6)
                                        }
.frame(height: meterHeight + 20)
                                    }
                                }
                            } else if doc.isAnalyzing {
                                HStack { ProgressView(); Text("Аналізую…") }.padding(.vertical, 4)
                            } else if let err = doc.errorMessage {
                                Text(err).foregroundColor(.red)
                            } else {
                                Text("Немає результату").foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                        .tabItem { Text(doc.url.lastPathComponent) }
                        .tag(doc.id)
                    }
                }
            }

            Spacer()
        }
        .padding()
        .onAppear {
            #if os(macOS)
            keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if event.keyCode == 49 && event.modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty {
                    NotificationCenter.default.post(name: playPauseNotification, object: nil)
                    return nil
                }
                return event
            }
            #endif
        }
        .onDisappear {
            #if os(macOS)
            if let m = keyMonitor { NSEvent.removeMonitor(m); keyMonitor = nil }
            #endif
        }
        .onReceive(NotificationCenter.default.publisher(for: playPauseNotification)) { _ in
            // Toggle play/pause and manage AVAudioPlayer
            guard let sel = model.selectedDocID, let doc = model.docs.first(where: { $0.id == sel }) else { return }
            let url = doc.url.resolvingSymlinksInPath()
            if audioPlayer == nil || audioPlayer?.url != url {
                audioPlayer = try? AVAudioPlayer(contentsOf: url)
                audioPlayer?.prepareToPlay()
                // Seek audio to current time
                if let res = doc.result { audioPlayer?.currentTime = currentTime(res: res) }
            }
            if isPlaying {
                audioPlayer?.pause()
                isPlaying = false
            } else {
                audioPlayer?.play()
                isPlaying = true
            }
        }
        .onReceive(Timer.publish(every: 0.016, on: .main, in: .common).autoconnect()) { _ in
            // Advance playhead either by timer or bind to audioPlayer time
            guard let res = model.docs.first(where: { $0.id == model.selectedDocID })?.result else { return }
            if let p = audioPlayer, p.isPlaying {
                playheadProgress = min(1.0, p.currentTime / max(res.duration, 0.000001))
            } else if isPlaying {
                let step = max(0.000001, 0.016 / max(res.duration, 0.000001))
                playheadProgress = min(1.0, playheadProgress + step)
            }
            if let cur = currentDB(res: res) {
                if let peak = peakHoldDB {
                    peakHoldDB = max(peak, cur)
                } else {
                    peakHoldDB = cur
                }
            }
            if playheadProgress >= 1.0 { isPlaying = false }
        }
    }

    private func pickFiles() {
        #if os(macOS)
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [UTType.audio]
        if panel.runModal() == .OK {
            model.addFiles(urls: panel.urls)
        }
        #endif
    }

    #if os(macOS)
    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        let id = UTType.fileURL.identifier
        for item in providers {
            item.loadItem(forTypeIdentifier: id, options: nil) { (data, error) in
                var maybeURL: URL?
                if let urlData = data as? Data, let str = String(data: urlData, encoding: .utf8), let url = URL(string: str) {
                    maybeURL = url
                } else if let url = data as? URL {
                    maybeURL = url
                }
                if let url = maybeURL {
                    DispatchQueue.main.async {
                        self.model.addFiles(urls: [url])
                    }
                }
            }
        }
        return true
    }
    #endif
    // MARK: - UI helpers and state
    @State private var amplitudeScale: CGFloat = 1.0
    @State private var isPlaying: Bool = false
    @State private var playheadProgress: Double = 0 // 0..1
    @State private var peakHoldDB: Double? = nil

    // Simple audio playback (AVAudioPlayer) synchronized to playhead
    @State private var audioPlayer: AVAudioPlayer?

    // Sizing
    private let meterHeight: CGFloat = 300

    private func metaLine(result: AnalysisResult, url: URL) -> String {
        var parts: [String] = []
        parts.append(String(format: "%.0f Гц", result.sampleRate))
        if let bd = result.bitDepth {
            parts.append("\(bd)-bit")
        } else if let br = result.bitrateKbps {
            parts.append("\(br) kbps")
        }
        return parts.joined(separator: " • ")
    }

    private func currentDB(res: AnalysisResult) -> Double? {
        guard !res.windowRMSdB.isEmpty else { return nil }
        let idx = max(0, min(res.windowRMSdB.count - 1, Int(Double(res.windowRMSdB.count - 1) * playheadProgress)))
        return res.windowRMSdB[idx]
    }

    private func currentTime(res: AnalysisResult) -> Double {
        max(0, min(res.duration, res.duration * playheadProgress))
    }

    private func formatTime(seconds: Double) -> String {
        let s = Int(seconds.rounded())
        let m = s / 60
        let r = s % 60
        return String(format: "%02d:%02d", m, r)
    }

    private var playPauseNotification: Notification.Name { Notification.Name("AAVPlayPauseToggle") }
}

#if os(macOS)
private struct DropZone: View {
    let title: String
    @Binding var isTargeted: Bool
    let onDrop: ([NSItemProvider]) -> Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
                .foregroundStyle(isTargeted ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary.opacity(0.5)))
            Text(title)
                .font(.caption)
                .foregroundStyle(isTargeted ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
        }
        .onDrop(of: [UTType.fileURL], isTargeted: $isTargeted, perform: onDrop)
    }
}
#endif

#Preview {
    ContentView()
}
