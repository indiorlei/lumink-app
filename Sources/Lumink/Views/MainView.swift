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
            Picker("Qualidade", selection: $compression) {
                ForEach(CompressionLevel.allCases) { level in
                    Text(level.label).tag(level.rawValue)
                }
            }
            .help("Qualidade das imagens no EPUB")

            Toggle(isOn: $imageModeDefault) {
                Label("Modo imagem", systemImage: "photo.on.rectangle")
            }
            .help("Modo imagem (HQ/mangá) para os próximos PDFs: uma imagem por página, sem OCR")

            Toggle(isOn: $onlyGenerate) {
                Label("Só gerar", systemImage: "tray.and.arrow.down")
            }
            .help("Só gerar o EPUB, sem enviar")

            if queue.hasPendingReview {
                Button("Processar todos") { queue.startAll() }
            }
            if queue.hasFinished {
                Button {
                    queue.clearFinished()
                } label: {
                    Label("Limpar concluídos", systemImage: "trash")
                }
                .help("Remover os itens concluídos da lista")
            }
            SettingsLink {
                Label("Configurações", systemImage: "gearshape")
            }
        }
    }
}
