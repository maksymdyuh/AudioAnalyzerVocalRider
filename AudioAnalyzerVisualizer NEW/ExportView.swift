import SwiftUI

struct ExportView: View {
    @EnvironmentObject var model: AppModel
    let docsToExport: [AppModel.Doc]
    @Environment(\.presentationMode) var presentationMode
    
    @State private var directory: URL
    @State private var prefix: String = "VR_"
    @State private var filename: String
    
    init(docs: [AppModel.Doc]) {
        self.docsToExport = docs
        let firstDir = docs.first?.url.deletingLastPathComponent() ?? URL(fileURLWithPath: NSHomeDirectory())
        _directory = State(initialValue: firstDir)
        let defaultName = docs.count == 1 ? docs.first!.url.deletingPathExtension().lastPathComponent : ""
        _filename = State(initialValue: defaultName)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(docsToExport.count == 1 ? "Експорт файлу" : "Експорт всіх файлів (\(docsToExport.count))")
                .font(.headline)
            
            HStack {
                Text("Куди зберегти:")
                Text(directory.path)
                    .truncationMode(.middle)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Вибрати…") {
                    let panel = NSOpenPanel()
                    panel.canChooseFiles = false
                    panel.canChooseDirectories = true
                    panel.canCreateDirectories = true
                    panel.directoryURL = directory
                    if panel.runModal() == .OK, let url = panel.url {
                        directory = url
                    }
                }
            }
            
            HStack {
                Text("Префікс:")
                TextField("Наприклад: VR_", text: $prefix)
            }
            
            if docsToExport.count == 1 {
                HStack {
                    Text("Назва файлу:")
                    TextField("Ім'я файлу", text: $filename)
                }
            }
            
            HStack {
                Button("Скасувати") {
                    presentationMode.wrappedValue.dismiss()
                }
                Spacer()
                Button("Експортувати") {
                    for doc in docsToExport {
                        let finalName = docsToExport.count == 1 ? filename : doc.url.deletingPathExtension().lastPathComponent
                        let rider = model.state(for: doc.id).riderAmount
                        
                        // Simple background export
                        DispatchQueue.global(qos: .userInitiated).async {
                            ExportProcessor.export(doc: doc, riderAmount: rider, to: directory, prefix: prefix, filename: finalName)
                        }
                    }
                    presentationMode.wrappedValue.dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 400)
    }
}
