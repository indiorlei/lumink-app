import SwiftUI

struct DependencyBanner: View {
    @Environment(QueueViewModel.self) private var queue

    var body: some View {
        let deps = queue.dependencies
        if !deps.calibreOK || !deps.ocrmypdfOK {
            VStack(alignment: .leading, spacing: 8) {
                if !deps.calibreOK {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Calibre não encontrado").bold()
                            Text("Necessário para converter PDFs com texto. O modo imagem funciona sem ele.")
                                .font(.caption)
                            HStack {
                                Link("Baixar o Calibre", destination: DependencyChecker.calibreDownloadURL)
                                Text("ou").foregroundStyle(.secondary)
                                CopyableCommand("brew install --cask calibre")
                            }
                            .font(.caption)
                        }
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    }
                }
                if !deps.ocrmypdfOK {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("ocrmypdf não encontrado").bold()
                            Text("PDFs escaneados usarão o OCR do macOS (Vision), que é mais lento e menos preciso. Para instalar:")
                                .font(.caption)
                            CopyableCommand("brew install ocrmypdf tesseract-lang")
                                .font(.caption)
                        }
                    } icon: {
                        Image(systemName: "info.circle.fill").foregroundStyle(.blue)
                    }
                }
                HStack {
                    Spacer()
                    Button("Verificar novamente") { queue.refreshDependencies() }
                        .controlSize(.small)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.yellow.opacity(0.12))
        }
    }
}

private struct CopyableCommand: View {
    let command: String
    init(_ command: String) { self.command = command }

    var body: some View {
        HStack(spacing: 4) {
            Text(command)
                .font(.caption.monospaced())
                .textSelection(.enabled)
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(command, forType: .string)
            } label: {
                Image(systemName: "doc.on.doc")
            }
            .buttonStyle(.borderless)
            .help("Copiar comando")
        }
    }
}
