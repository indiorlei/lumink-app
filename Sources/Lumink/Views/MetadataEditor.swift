import SwiftUI

/// Título, autor e idioma editáveis antes de processar (vão para o EPUB e o e-mail).
struct MetadataEditor: View {
    @Bindable var job: BookJob
    let onStart: () -> Void

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 6) {
            GridRow {
                Text("Título").foregroundStyle(.secondary)
                TextField("Título", text: $job.title)
                    .textFieldStyle(.roundedBorder)
            }
            GridRow {
                Text("Autor").foregroundStyle(.secondary)
                TextField("Autor", text: $job.author)
                    .textFieldStyle(.roundedBorder)
            }
            GridRow {
                Text("Idioma").foregroundStyle(.secondary)
                HStack {
                    Picker("Idioma", selection: $job.language) {
                        Text("Detectar sozinho").tag(String?.none)
                        Divider()
                        ForEach(BookLanguage.choices, id: \.self) { code in
                            Text(BookLanguage.menuName(code)).tag(Optional(code))
                        }
                    }
                    .labelsHidden()
                    .fixedSize()
                    .help("Vai para o EPUB: o Kindle usa o idioma para escolher o dicionário e a hifenização")
                    Toggle("Modo imagem (HQ/mangá)", isOn: $job.imageMode)
                        .help("Pula o OCR e gera um EPUB de layout fixo com uma imagem por página")
                    Spacer()
                    Button("Processar", action: onStart)
                        .buttonStyle(.borderedProminent)
                        .disabled(job.title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .font(.callout)
    }
}
