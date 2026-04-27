import Foundation
import Combine
import SwiftUI

final class AppModel: ObservableObject {
    struct Doc: Identifiable, Equatable {
        let id: UUID = UUID()
        var url: URL
        var result: AnalysisResult?
        var isAnalyzing: Bool = false
        var errorMessage: String?
    }

    struct ViewState: Equatable {
        var timeZoom: CGFloat = 1.0
        var timeStart: CGFloat = 0.0
        var amplitudeScale: CGFloat = 1.0
        var playheadProgress: Double = 0.0 // 0..1
        var riderAmount: Double = 0.0 // 0.0 .. 1.0 (Vocal Rider flatten amount)
    }

    @Published var docs: [Doc] = []
    @Published var selectedDocID: UUID?
    @Published var viewStates: [UUID: ViewState] = [:]

    let allowedExtensions = ["wav", "aiff", "aif", "caf", "m4a", "mp3"]

    func state(for id: UUID) -> ViewState { viewStates[id] ?? ViewState() }
    @MainActor
    func setState(for id: UUID, _ s: ViewState) { viewStates[id] = s }
    @MainActor
    func updateState(for id: UUID, _ mutate: (inout ViewState) -> Void) {
        var s = viewStates[id] ?? ViewState()
        mutate(&s)
        viewStates[id] = s
    }

    func addFiles(urls: [URL]) {
        var newDocs: [Doc] = []
        let existing = Set(docs.map { $0.url })
        for url in urls {
            let ext = url.pathExtension.lowercased()
            guard allowedExtensions.contains(ext), !existing.contains(url) else { continue }
            let d = Doc(url: url)
            newDocs.append(d)
            viewStates[d.id] = ViewState()
        }
        guard !newDocs.isEmpty else { return }
        docs.append(contentsOf: newDocs)
        if let last = newDocs.last { selectedDocID = last.id }
        for newDoc in newDocs {
            if let idx = docs.firstIndex(where: { $0.id == newDoc.id }) {
                Task { await analyze(docIndex: idx) }
            }
        }
    }

    @MainActor
    func clearAll() {
        docs.removeAll()
        selectedDocID = nil
        viewStates.removeAll()
    }

    func analyzeCurrent() async {
        guard let selID = selectedDocID, let idx = docs.firstIndex(where: { $0.id == selID }) else { return }
        await analyze(docIndex: idx)
    }

    func analyze(docIndex idx: Int) async {
        let url = docs[idx].url
        await MainActor.run {
            docs[idx].isAnalyzing = true
            docs[idx].errorMessage = nil
        }
        do {
            let res = try await AnalyzerService.analyze(url: url, preferPython: true, windowMs: 20)
            // Enrich with bit depth / bitrate if not provided by backend
            let enriched = await enrich(result: res, url: url)
            await MainActor.run {
                docs[idx].result = enriched
            }
        } catch {
            await MainActor.run {
                docs[idx].errorMessage = error.localizedDescription
            }
        }
        await MainActor.run {
            docs[idx].isAnalyzing = false
        }
    }

    func analyzeAllPending() async {
      for i in docs.indices {
        if docs[i].result == nil && docs[i].isAnalyzing == false {
            await analyze(docIndex: i)
        }
      }
    }

    func closeDoc(id: UUID) {
        if let idx = docs.firstIndex(where: { $0.id == id }) {
            docs.remove(at: idx)
            viewStates[id] = nil
            if selectedDocID == id {
                selectedDocID = docs.first?.id
            }
        }
    }

    // Derive bit depth / bitrate using AVFoundation if possible
    private func enrich(result: AnalysisResult, url: URL) async -> AnalysisResult {
        var r = result
        if r.bitDepth == nil || r.bitrateKbps == nil {
            let info = await AudioFileInfoInspector.inspect(url: url)
            if r.bitDepth == nil { r.bitDepth = info.bitDepth }
            if r.bitrateKbps == nil { r.bitrateKbps = info.bitrateKbps }
        }
        
        // --- Додаємо обчислення Vocal Rider (Clip Gain) ---
        let params = GainSuggester.Params(
            targetDB: -18.0,       // Цільовий рівень
            thresholdDB: -40.0,    // Не чіпати тишу (тільки шум)
            minGainDB: -12.0,      // Максимальне зменшення
            maxGainDB: 12.0,       // Максимальне підсилення
            attackMs: 5.0,         // Швидкість реакції на гучний звук
            releaseMs: 100.0,      // Швидкість реакції на тихий звук
            windowMs: Double(r.windowMs)
        )
        r.suggestedGain = GainSuggester.suggest(windowRMSdB: r.windowRMSdB, params: params)
        print("✅ Vocal Rider Computed! Envelope size: \(r.suggestedGain?.count ?? 0) windows.")
        
        return r
    }
}
