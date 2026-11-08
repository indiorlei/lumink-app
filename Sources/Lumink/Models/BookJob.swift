import Foundation
import Observation

/// Um item da fila. Vive no MainActor; o pipeline atualiza via `JobReporter`.
@MainActor
@Observable
final class BookJob: Identifiable {
    let id = UUID()
    let sourceURL: URL
    let originalSize: Int64

    var title: String
    var author: String
    var imageMode: Bool

    var stage: PipelineStage = .waiting
    /// `nil` = progresso indeterminado.
    var progress: Double? = 0
    var status: JobStatus = .queued
    var detail: String = ""
    var finalSize: Int64?
    var outputURL: URL?

    init(sourceURL: URL, title: String, author: String, imageMode: Bool) {
        self.sourceURL = sourceURL
        self.title = title
        self.author = author
        self.imageMode = imageMode
        let attrs = try? FileManager.default.attributesOfItem(atPath: sourceURL.path)
        self.originalSize = (attrs?[.size] as? NSNumber)?.int64Value ?? 0
    }

    var fileName: String { sourceURL.lastPathComponent }

    func resetForRetry() {
        stage = .waiting
        progress = 0
        status = .queued
        detail = ""
        finalSize = nil
        outputURL = nil
    }
}

/// Ponte thread-safe do pipeline (fora do MainActor) para o `BookJob`.
struct JobReporter: Sendable {
    let job: BookJob

    func stage(_ stage: PipelineStage, detail: String? = nil) async {
        await MainActor.run {
            job.stage = stage
            job.progress = 0
            if let detail { job.detail = detail }
        }
    }

    /// Chamado com frequência (ex.: a cada linha do stdout). Ignora atualizações
    /// atrasadas de uma etapa que já terminou.
    func progress(_ value: Double?, in stage: PipelineStage) {
        Task { @MainActor in
            guard job.stage == stage else { return }
            job.progress = value.map { min(max($0, 0), 1) }
        }
    }

    func detail(_ text: String) async {
        await MainActor.run { job.detail = text }
    }

    func snapshot() async -> (title: String, author: String, imageMode: Bool) {
        await MainActor.run { (job.title, job.author, job.imageMode) }
    }
}
