import SwiftUI
import UniformTypeIdentifiers

struct MainView: View {
    @Environment(QueueViewModel.self) private var queue
    @AppStorage(SettingsKey.compressionLevel) private var compression = SettingsDefault.compressionLevel
    @AppStorage(SettingsKey.onlyGenerate) private var onlyGenerate = false
    @AppStorage(SettingsKey.imageModeDefault) private var imageModeDefault = false
    @State private var showImporter = false

    var body: some View {
        VStack(spacing: 0) {
            DependencyBanner()
            DropZoneView(compact: !queue.jobs.isEmpty) { showImporter = true }
                .padding()
            if !queue.jobs.isEmpty {
                List {
                    ForEach(queue.jobs) { job in
                        JobRowView(job: job)
                            .listRowSeparator(.visible)
                    }
                }
                .listStyle(.inset)
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            queue.add(urls: urls)
            return true
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.pdf], allowsMultipleSelection: true) { result in
            if case .success(let urls) = result { queue.add(urls: urls) }
        }
        .toolbar { toolbar }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Picker(loc("Qualidade", "Quality"), selection: $compression) {
                ForEach(CompressionLevel.allCases) { level in
                    Text(level.label).tag(level.rawValue)
                }
            }
            .help(loc("Qualidade das imagens no EPUB", "Image quality in the EPUB"))

            Toggle(isOn: $imageModeDefault) {
                Label(loc("Modo imagem", "Image mode"), systemImage: "photo.on.rectangle")
            }
            .help(loc("Modo imagem (HQ/mangá) para os próximos PDFs: uma imagem por página, sem OCR", "Image mode (comics/manga) for the next PDFs: one image per page, no OCR"))

            Toggle(isOn: $onlyGenerate) {
                Label(loc("Só gerar", "Only generate"), systemImage: "tray.and.arrow.down")
            }
            .help(loc("Só gerar o EPUB, sem enviar", "Only generate the EPUB, without sending it"))

            if queue.hasPendingReview {
                Button(loc("Processar todos", "Process all")) { queue.startAll() }
            }
            if queue.hasFinished {
                Button {
                    queue.clearFinished()
                } label: {
                    Label(loc("Limpar concluídos", "Clear finished"), systemImage: "trash")
                }
                .help(loc("Remover os itens concluídos da lista", "Remove finished items from the list"))
            }
            SettingsLink {
                Label(loc("Configurações", "Settings"), systemImage: "gearshape")
            }
        }
    }
}
