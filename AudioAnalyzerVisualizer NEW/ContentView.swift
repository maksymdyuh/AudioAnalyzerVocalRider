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
    @State private var eventMonitor: Any?
    #endif

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {

            // Custom browser-like tab strip
            if !model.docs.isEmpty {
                TabStripView(docs: model.docs, selection: $model.selectedDocID, onClose: { id in
                    model.closeDoc(id: id)
                })
            }

            if model.docs.contains(where: { $0.isAnalyzing }) {
                HStack { ProgressView(); Text("Аналізую…") }.padding(.vertical, 4)
            }

            if !model.docs.isEmpty {
                // Обираємо активний документ
                if let sel = model.selectedDocID ?? model.docs.first?.id,
                   let doc = model.docs.first(where: { $0.id == sel }) {
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
Text(String(format: "Середній рівень: %.1f dBFS", res.averageRMSdB))
                                        .font(.headline)
                                    Text(metaLine(result: res, url: doc.url))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    // Time ruler and current/total time
                                        TimeRulerView(duration: res.duration, timeZoom: timeZoom, timeStart: timeStart)
                                            .frame(height: 20)

                                            ZStack {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(LinearGradient(colors: [Color.black.opacity(0.03), Color.black.opacity(0.06)], startPoint: .top, endPoint: .bottom))
                                            HStack(spacing: 6) {
                                                WaveformView(
                                                    samplesDB: res.windowRMSdB,
                                                    suggestedGain: res.suggestedGain, // Передаємо криву Vocal Rider сюди!
                                                    lineColor: .accentColor,
                                                    showGrid: true,
                                                    amplitudeScale: amplitudeScale,
                                                    timeZoom: timeZoom,
                                                    timeStart: timeStart,
                                                    duration: res.duration,
                                                    sampleRate: res.sampleRate,
                                                    audioURL: doc.url
                                                )
                                                    .padding(.vertical, 8)
                                                    .padding(.horizontal, 4)
                                                    .overlay(
GeometryReader { geo in
                                                    ZStack(alignment: .topLeading) {
                                                        // Keep overlayWidth updated
                                                        Color.clear
                                                            .onAppear { overlayWidth = max(geo.size.width, 1) }
                                                            .onChange(of: geo.size.width) { newW in
                                                                overlayWidth = max(newW, 1)
                                                            }

                                                        let f = max(1.0 / max(timeZoom, 0.000001), 0.000001)
                                                        let rel = (playheadProgress - timeStart) / f
                                                        let x = max(0, min(geo.size.width, geo.size.width * rel))
                                                        Path { p in
                                                            p.move(to: CGPoint(x: x, y: 0))
                                                            p.addLine(to: CGPoint(x: x, y: geo.size.height))
                                                        }
                                                        .stroke(Color.white, lineWidth: 1.5)

                                                        // Wheel zoom/pan handler (behind tap gesture)
                                                        #if os(macOS)
                                                        WheelZoomView(
                                                            onZoom: { scaleDelta, relX in
                                                                let f0 = max(1.0 / max(timeZoom, 0.000001), 0.000001)
                                                                var z = timeZoom * scaleDelta
                                                                z = max(1.0, min(64.0, z))
                                                                let f1 = max(1.0 / max(z, 0.000001), 0.000001)
                                                                let centerAbs = timeStart + f0 * clamp(relX, 0, 1)
                                                                var newStart = centerAbs - f1 * clamp(relX, 0, 1)
                                                                newStart = clamp(newStart, 0, 1 - f1)
                                                                timeZoom = z
                                                                timeStart = newStart
                                                            },
                                                            onPan: { deltaRel in
                                                                let f = max(1.0 / max(timeZoom, 0.000001), 0.000001)
                                                                let newStart = clamp(timeStart + deltaRel * f, 0, 1 - f)
                                                                timeStart = newStart
                                                            }
                                                        )
                                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                                        // Mouse position tracker to set zoom center under cursor
                                                        MouseTrackingView { relX in
                                                            cursorRelX = relX
                                                            cursorInsideWaveform = true
                                                        }
                                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                                        .allowsHitTesting(false)
                                                        #endif

                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(DragGesture(minimumDistance: 0).onEnded { v in
                            let localX = max(0, min(v.location.x, geo.size.width))
                            let f = max(1.0 / max(timeZoom, 0.000001), 0.000001)
                            let rel = localX / max(geo.size.width, 0.000001)
                            let progress = max(0, min(1, timeStart + f * rel))
                            playheadProgress = progress
                            // Persist playhead immediately
                            if let sel = model.selectedDocID {
                                model.updateState(for: sel) { s in s.playheadProgress = progress }
                            }
                            audioPlayer?.currentTime = res.duration * progress
                        })
                        #if os(macOS)
                        .onHover { inside in
                            cursorInsideWaveform = inside
                        }
                        #endif
                                                        // Horizontal pan (drag gesture)
                                                        .simultaneousGesture(DragGesture(minimumDistance: 2).onChanged { v in
                                                            let f = max(1.0 / max(timeZoom, 0.000001), 0.000001)
                                                            if !isPanning {
                                                                panStartSnapshot = timeStart
                                                                isPanning = true
                                                            }
                                                            let delta = -v.translation.width / max(geo.size.width, 0.000001) * f
                                                            let newStart = clamp(panStartSnapshot + delta, 0, 1 - f)
                                                            timeStart = newStart
                                                        }.onEnded { _ in
                                                            isPanning = false
                                                        })
// Pinch to zoom (centered at cursor)
                                                        .simultaneousGesture(MagnificationGesture().onChanged { scale in
                                                            if !isZooming {
                                                                zoomStartSnapshot = timeZoom
                                                                isZooming = true
                                                                zoomCenterRelSnapshot = cursorRelX
                                                            }
                                                            var z = zoomStartSnapshot * scale
                                                            z = max(1.0, min(64.0, z))
                                                            let f0 = max(1.0 / max(zoomStartSnapshot, 0.000001), 0.000001)
                                                            let f1 = max(1.0 / max(z, 0.000001), 0.000001)
                                                            // Keep time under cursor fixed
                                                            let rel = clamp(zoomCenterRelSnapshot, 0, 1)
                                                            let centerAbs = timeStart + f0 * rel
                                                            var newStart = centerAbs - f1 * rel
                                                            newStart = clamp(newStart, 0, 1 - f1)
                                                            timeZoom = z
                                                            timeStart = newStart
                                                        }.onEnded { _ in
                                                            isZooming = false
                                                        })
                                                    }
                                                }
                                                )
                                            // Vertical zoom slider (same height as meter)
                                            VStack {
                                                Slider(value: $amplitudeScale, in: 0.5...5.0)
                                                    .rotationEffect(.degrees(-90))
                                                    .frame(maxHeight: .infinity)
                                                    .scaleEffect(1.4)
                                                    .padding(.horizontal, 4)
                                            }
                                            .frame(width: 56)

                                            GainMeterView(currentDB: currentDB(res: res), peakHoldDB: peakHoldDB)
                                                .frame(width: 26)
                                                .frame(maxHeight: .infinity)
                                        }
                                    }
                                    .overlay(alignment: .topLeading) {
                                        Text("\(formatTime(seconds: currentTime(res: res)))/\(formatTime(seconds: res.duration))")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .padding(6)
                                    }
                                    .frame(minHeight: meterMinHeight)
                                    .frame(maxHeight: .infinity)
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
                }
            }

            Spacer()
        }
        .padding()
        .onAppear {
            // Restore per-doc view state when content appears
            if let sel = model.selectedDocID {
                let s = model.state(for: sel)
                self.timeZoom = s.timeZoom
                self.timeStart = s.timeStart
                self.amplitudeScale = s.amplitudeScale
                self.playheadProgress = s.playheadProgress
                self.lastSelectedID = sel
            }
            #if os(macOS)
            keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if event.keyCode == 49 && event.modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty {
                    NotificationCenter.default.post(name: playPauseNotification, object: nil)
                    return nil
                }
                return event
            }
            eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel, .magnify]) { ev in
                // Only handle gestures when mouse is over the waveform overlay area
                guard cursorInsideWaveform else { return ev }
                // Also require the event's window to be our frontmost app window to avoid global capture
                guard NSApplication.shared.isActive else { return ev }
                let f0 = max(1.0 / max(timeZoom, 0.000001), 0.000001)
                if ev.type == .scrollWheel {
                    let dx = ev.scrollingDeltaX
                    let dy = ev.scrollingDeltaY
                    if abs(dx) > abs(dy) {
                        // Pan horizontally by dx
                        let deltaRel = -CGFloat(dx) / max(overlayWidth, 1)
                        let newStart = clamp(timeStart + deltaRel * f0, 0, 1 - f0)
                        timeStart = newStart
                        return nil
                    } else {
                        // Zoom vertically by dy around cursor
                        var z = timeZoom * pow(1.08, dy / 10.0)
                        z = max(1.0, min(64.0, z))
                        let f1 = max(1.0 / max(z, 0.000001), 0.000001)
                        let rel = clamp(cursorRelX, 0, 1)
                        let centerAbs = timeStart + f0 * rel
                        var newStart = centerAbs - f1 * rel
                        newStart = clamp(newStart, 0, 1 - f1)
                        timeZoom = z
                        timeStart = newStart
                        return nil
                    }
                } else if ev.type == .magnify {
                    var z = timeZoom * (1.0 + ev.magnification)
                    z = max(1.0, min(64.0, z))
                    let f1 = max(1.0 / max(z, 0.000001), 0.000001)
                    let rel = clamp(cursorRelX, 0, 1)
                    let centerAbs = timeStart + f0 * rel
                    var newStart = centerAbs - f1 * rel
                    newStart = clamp(newStart, 0, 1 - f1)
                    timeZoom = z
                    timeStart = newStart
                    return nil
                }
                return ev
            }
            #endif
        }
        .onChange(of: model.selectedDocID) { newID in
            // Pause any current playback when switching files
            if isPlaying { audioPlayer?.pause(); isPlaying = false }
            // Persist state of previous selection
            if let prev = lastSelectedID {
                model.updateState(for: prev) { s in
                    s.timeZoom = self.timeZoom
                    s.timeStart = self.timeStart
                    s.amplitudeScale = self.amplitudeScale
                    s.playheadProgress = self.playheadProgress
                }
            }
            // Restore state of new selection
            if let id = newID {
                let s = model.state(for: id)
                self.timeZoom = s.timeZoom
                self.timeStart = s.timeStart
                self.amplitudeScale = s.amplitudeScale
                self.playheadProgress = s.playheadProgress
                self.lastSelectedID = id
                // Seek player position to this doc's playhead if same audio is loaded
                if let doc = model.docs.first(where: { $0.id == id }), let res = doc.result {
                    if audioPlayer?.url == doc.url { audioPlayer?.currentTime = currentTime(res: res) }
                }
            }
        }
        .onDisappear {
            // Persist current state into model
            if let sel = model.selectedDocID {
                model.updateState(for: sel) { s in
                    s.timeZoom = self.timeZoom
                    s.timeStart = self.timeStart
                    s.amplitudeScale = self.amplitudeScale
                }
            }
            #if os(macOS)
            if let m = keyMonitor { NSEvent.removeMonitor(m); keyMonitor = nil }
            if let e = eventMonitor { NSEvent.removeMonitor(e); eventMonitor = nil }
            #endif
        }
        .onReceive(NotificationCenter.default.publisher(for: playPauseNotification)) { _ in
            // Toggle play/pause and manage AVAudioPlayer
            guard let sel = model.selectedDocID, let doc = model.docs.first(where: { $0.id == sel }) else { return }
            // Persist state for current doc on interaction
            model.updateState(for: sel) { s in
                s.timeZoom = self.timeZoom
                s.timeStart = self.timeStart
                s.amplitudeScale = self.amplitudeScale
            }
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
                // Always start from playhead position
                if let res = doc.result {
                    audioPlayer?.currentTime = currentTime(res: res)
                }
                audioPlayer?.play()
                isPlaying = true
            }
        }
        .onReceive(Timer.publish(every: 0.016, on: .main, in: .common).autoconnect()) { _ in
            // Advance playhead either by timer or bind to audioPlayer time
            guard let sel = model.selectedDocID, let doc = model.docs.first(where: { $0.id == sel }), let res = doc.result else { return }
            if let p = audioPlayer, p.isPlaying {
                playheadProgress = min(1.0, p.currentTime / max(res.duration, 0.000001))
            } else if isPlaying {
                let step = max(0.000001, 0.016 / max(res.duration, 0.000001))
                playheadProgress = min(1.0, playheadProgress + step)
            }
            // Persist state periodically while doc is visible
            model.updateState(for: sel) { s in
                s.timeZoom = self.timeZoom
                s.timeStart = self.timeStart
                s.amplitudeScale = self.amplitudeScale
                s.playheadProgress = self.playheadProgress
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
    // Per-doc view state cache (backed by model.viewStates)
    @State private var amplitudeScale: CGFloat = 1.0
    @State private var isPlaying: Bool = false
    @State private var playheadProgress: Double = 0 // 0..1
    @State private var peakHoldDB: Double? = nil

    // Time navigation state (horizontal zoom and pan) — kept per selected doc
    @State private var timeZoom: CGFloat = 1.0
    @State private var timeStart: CGFloat = 0.0
    @State private var panStartSnapshot: CGFloat = 0.0
    @State private var isPanning: Bool = false
    @State private var zoomStartSnapshot: CGFloat = 1.0
    @State private var isZooming: Bool = false
    @State private var cursorRelX: CGFloat = 0.5
    @State private var zoomCenterRelSnapshot: CGFloat = 0.5
    @State private var cursorInsideWaveform: Bool = false
    @State private var overlayWidth: CGFloat = 1.0
    @State private var lastSelectedID: UUID? = nil

    // Simple audio playback (AVAudioPlayer) synchronized to playhead
    @State private var audioPlayer: AVAudioPlayer?

    // Sizing
    // Height grows with window; this is a preferred minimum, not a fixed value
    private let meterMinHeight: CGFloat = 240

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

    // Helpers
    private func clamp(_ x: CGFloat, _ a: CGFloat, _ b: CGFloat) -> CGFloat { max(a, min(b, x)) }
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
