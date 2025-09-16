import SwiftUI

struct TabStripView: View {
    let docs: [AppModel.Doc]
    @Binding var selection: UUID?
    var onClose: (UUID) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(docs, id: \.id) { doc in
                            TabChip(
                                title: doc.url.lastPathComponent,
                                isSelected: doc.id == selection,
                                onSelect: { selection = doc.id },
                                onClose: { onClose(doc.id) }
                            )
                            .id(doc.id)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                }
                .onAppear {
                    if let sel = selection { proxy.scrollTo(sel, anchor: .center) }
                }
                .onChange(of: selection) { newSel in
                    if let sel = newSel {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            proxy.scrollTo(sel, anchor: .center)
                        }
                    }
                }
            }
            Divider()
        }
        .background(.thinMaterial)
    }
}

private struct TabChip: View {
    let title: String
    let isSelected: Bool
    let onSelect: () -> Void
    let onClose: () -> Void
    #if os(macOS)
    @State private var hovering = false
    #endif

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .lineLimit(1)
                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
            #if os(macOS)
            if hovering || isSelected {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Закрити вкладку")
            }
            #else
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
            }
            .buttonStyle(.plain)
            #endif
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(isSelected ? Color.accentColor.opacity(0.5) : Color.secondary.opacity(0.2), lineWidth: isSelected ? 1 : 0.5)
        )
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
        #if os(macOS)
        .onHover { hovering = $0 }
        #endif
    }
}
