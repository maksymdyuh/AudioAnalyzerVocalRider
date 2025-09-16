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

    @Published var docs: [Doc] = []
    @Published var selectedDocID: UUID?

    let allowedExtensions = ["wav", "aiff", "aif", "caf", "m4a", "mp3"]

    func addFiles(urls: [URL]) {
        var newDocs: [Doc] = []
        let existing = Set(docs.map { $0.url })
        for url in urls {
            let ext = url.pathExtension.lowercased()
            guard allowedExtensions.contains(ext), !existing.contains(url) else { continue }
            newDocs.append(Doc(url: url))
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
        return r
    }
}
