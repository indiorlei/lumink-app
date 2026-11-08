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
                            Text(loc("Calibre não encontrado", "Calibre not found")).bold()
                            Text(loc("Necessário para converter PDFs com texto. O modo imagem funciona sem ele.", "Needed to convert PDFs with text. Image mode works without it."))
                                .font(.caption)
                            HStack {
                                Link(loc("Baixar o Calibre", "Download Calibre"), destination: DependencyChecker.calibreDownloadURL)
                                Text(loc("ou", "or")).foregroundStyle(.secondary)
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
                            Text(loc("ocrmypdf não encontrado", "ocrmypdf not found")).bold()
                            Text(loc("PDFs escaneados usarão o OCR do macOS (Vision), que é mais lento e menos preciso. Para instalar:", "Scanned PDFs will use the macOS OCR (Vision), which is slower and less accurate. To install it:"))
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
                    Button(loc("Verificar novamente", "Check again")) { queue.refreshDependencies() }
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
            .help(loc("Copiar comando", "Copy command"))
        }
    }
}
