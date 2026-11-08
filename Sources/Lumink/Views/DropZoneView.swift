import SwiftUI

struct DropZoneView: View {
    let compact: Bool
    let choose: () -> Void

    var body: some View {
        Group {
            if compact {
                HStack {
                    Image(systemName: "arrow.down.doc")
                    Text(loc("Arraste mais PDFs para esta janela", "Drag more PDFs into this window"))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(loc("Escolher PDF…", "Choose PDF…"), action: choose)
                }
                .padding(12)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "arrow.down.doc")
                        .font(.system(size: 44, weight: .light))
                        .foregroundStyle(.secondary)
                    Text(loc("Arraste seus PDFs aqui", "Drag your PDFs here"))
                        .font(.title3)
                    Text(loc("Vários arquivos de uma vez são processados em fila.", "Several files at once are processed in a queue."))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Button(loc("Escolher PDF…", "Choose PDF…"), action: choose)
                        .controlSize(.large)
                        .keyboardShortcut("o")
                }
                .frame(maxWidth: .infinity, minHeight: 220)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                .foregroundStyle(.tertiary)
        )
    }
}
