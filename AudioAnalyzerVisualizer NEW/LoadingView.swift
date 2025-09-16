import SwiftUI

struct LoadingView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        VStack(spacing: 16) {
            Text("Завантаження аналізу…")
                .font(.title2)
                .bold()
            Text(progressLine)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            ProgressView(value: Double(done), total: Double(total))
                .frame(maxWidth: 360)
                .padding(.top, 8)

            if !analyzingNames.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(analyzingNames, id: \.self) { name in
                            HStack(spacing: 8) {
                                ProgressView()
                                    .controlSize(.small)
                                Text(name)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
                .frame(maxHeight: 140)
                .frame(maxWidth: 460)
            }
        }
        .padding(24)
        .frame(minWidth: 600, minHeight: 400)
        .task {
            // На всякий випадок — запуск аналізу для всіх не запущених
            await model.analyzeAllPending()
        }
    }

    private var total: Int { model.docs.count }
    private var done: Int { model.docs.filter { $0.result != nil || $0.errorMessage != nil }.count }
    private var analyzingNames: [String] {
        model.docs.filter { $0.isAnalyzing && ($0.result == nil) }
            .map { $0.url.lastPathComponent }
    }
    private var progressLine: String { "Готово: \(done) з \(total)" }
}
