import SwiftUI

/// Título, autor e idioma editáveis antes de processar (vão para o EPUB e o e-mail).
struct MetadataEditor: View {
    @Bindable var job: BookJob
    let onStart: () -> Void

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 6) {
            GridRow {
                Text(loc("Título", "Title")).foregroundStyle(.secondary)
                TextField(loc("Título", "Title"), text: $job.title)
                    .textFieldStyle(.roundedBorder)
            }
            GridRow {
                Text(loc("Autor", "Author")).foregroundStyle(.secondary)
                TextField(loc("Autor", "Author"), text: $job.author)
                    .textFieldStyle(.roundedBorder)
            }
            GridRow {
                Text(loc("Idioma", "Language")).foregroundStyle(.secondary)
                HStack {
                    Picker(loc("Idioma", "Language"), selection: $job.language) {
                        Text(loc("Detectar sozinho", "Detect automatically")).tag(String?.none)
                        Divider()
                        ForEach(BookLanguage.choices, id: \.self) { code in
                            Text(BookLanguage.menuName(code)).tag(Optional(code))
                        }
                    }
                    .labelsHidden()
                    .fixedSize()
                    .help(loc("Vai para o EPUB: o Kindle usa o idioma para escolher o dicionário e a hifenização",
                              "Goes into the EPUB: the Kindle uses the language to pick the dictionary and hyphenation"))
                    Toggle(loc("Modo imagem (HQ/mangá)", "Image mode (comics/manga)"), isOn: $job.imageMode)
                        .help(loc("Pula o OCR e gera um EPUB de layout fixo com uma imagem por página", "Skips OCR and builds a fixed-layout EPUB with one image per page"))
                    Spacer()
                    Button(loc("Processar", "Process"), action: onStart)
                        .buttonStyle(.borderedProminent)
                        .disabled(job.title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .font(.callout)
    }
}
