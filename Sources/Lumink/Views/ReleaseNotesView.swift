import SwiftUI

/// Janela loc("Novidades do Lumink", "What's New in Lumink").
struct ReleaseNotesView: View {
    var notes: [ReleaseNote] = ReleaseNotes.all
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header
                    ForEach(notes) { note in
                        Divider()
                        ReleaseBlock(note: note)
                    }
                }
                .padding(28)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Divider()
            HStack {
                Spacer()
                Button(loc("Continuar", "Continue")) { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(16)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(loc("Novidades do Lumink", "What's New in Lumink"))
                .font(.system(size: 26, weight: .semibold, design: .serif))
            Text(loc("A luz que leva o seu livro até a tinta.", "The light that carries your book to the ink."))
                .font(.callout).foregroundStyle(.secondary)
        }
    }
}

private struct ReleaseBlock: View {
    let note: ReleaseNote

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(loc("Versão \(note.version)", "Version \(note.version)"))
                        .font(.caption.monospaced().weight(.medium))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(.tint.opacity(0.15), in: .rect(cornerRadius: 4))
                    Text(note.date).font(.caption).foregroundStyle(.secondary)
                }
                Text(note.headline).font(.title2.weight(.semibold))
            }
            ForEach(note.sections, id: \.title) { section in
                VStack(alignment: .leading, spacing: 6) {
                    Text(section.title).font(.headline)
                    ForEach(section.items, id: \.self) { item in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("•").foregroundStyle(.secondary)
                            Text(LocalizedStringKey(item))   // aceita *itálico* e **negrito**
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
        .textSelection(.enabled)
    }
}

/// Abre as novidades na primeira abertura de cada versão.
struct ShowReleaseNotesOnUpdate: ViewModifier {
    @Environment(\.openWindow) private var openWindow

    func body(content: Content) -> some View {
        content.task {
            if ReleaseNotes.consumeShouldShowOnLaunch() {
                openWindow(id: ReleaseNotesWindow.id)
            }
        }
    }
}

enum ReleaseNotesWindow {
    static let id = "release-notes"
}

/// Item loc("Novidades do Lumink…", "What's New in Lumink…") no menu do app.
struct ReleaseNotesCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(after: .appInfo) {
            Button(loc("Novidades do Lumink…", "What's New in Lumink…")) { openWindow(id: ReleaseNotesWindow.id) }
        }
    }
}
