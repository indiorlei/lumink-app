import SwiftUI

struct DropZoneView: View {
    let compact: Bool
    let choose: () -> Void

    var body: some View {
        Group {
            if compact {
                HStack {
                    Image(systemName: "arrow.down.doc")
                    Text("Arraste mais PDFs para esta janela")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Escolher PDF…", action: choose)
                }
                .padding(12)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "arrow.down.doc")
                        .font(.system(size: 44, weight: .light))
                        .foregroundStyle(.secondary)
                    Text("Arraste seus PDFs aqui")
                        .font(.title3)
                    Text("Vários arquivos de uma vez são processados em fila.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Button("Escolher PDF…", action: choose)
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
