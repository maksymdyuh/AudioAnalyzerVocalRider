import SwiftUI
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#endif

#if os(macOS)
private struct StartDropZone: View {
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

struct StartView: View {
    @EnvironmentObject var model: AppModel
    #if os(macOS)
    @State private var isTargeted: Bool = false
    #endif

    var body: some View {
        VStack(spacing: 16) {
            Text("Аналізатор гучності аудіо")
                .font(.title)
                .bold()
            Text("Оберіть або перетягніть аудіофайли (WAV/AIFF/CAF/MP3/M4A)")
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Button {
                    pickFiles()
                } label: {
                    Label("Відкрити аудіо…", systemImage: "folder")
                }
                .buttonStyle(.bordered)

                Button(role: .none) {
                    if !model.docs.isEmpty {
                        Task { await model.analyzeAllPending() }
                    }
                } label: {
                    Label("Аналізувати", systemImage: "waveform")
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.docs.isEmpty)
            }
            .padding(.top, 8)

            #if os(macOS)
            StartDropZone(title: model.docs.isEmpty ? "Перетягніть аудіофайли сюди" : "Перетягніть, щоб додати ще файли",
                          isTargeted: $isTargeted) { providers in
                handleDrop(providers)
            }
            .frame(height: 120)
            #endif

            if !model.docs.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Обрано файлів: \(model.docs.count)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(24)
        .frame(minWidth: 540, minHeight: 360)
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
}
