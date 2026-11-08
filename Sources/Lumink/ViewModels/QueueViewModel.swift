import Foundation
import Observation
import AppKit

/// Fila serial: processa um PDF por vez.
@MainActor
@Observable
final class QueueViewModel {
    private(set) var jobs: [BookJob] = []
    var dependencies = DependencyStatus()

    private var worker: Task<Void, Never>?
    private var currentTask: Task<Void, Never>?
    private var currentJobID: UUID?

    init() {
        SettingsDefault.register()
        refreshDependencies()
    }

    func refreshDependencies() {
        dependencies = DependencyChecker.check()
        Log.app.info("Dependências: calibre=\(self.dependencies.calibrePath ?? "ausente", privacy: .public) ocrmypdf=\(self.dependencies.ocrmypdfPath ?? "ausente", privacy: .public)")
    }

    // MARK: - Adicionar

    func add(urls: [URL]) {
        let pdfs = urls.filter { $0.pathExtension.lowercased() == "pdf" }
        let defaults = UserDefaults.standard
        let review = defaults.bool(forKey: SettingsKey.reviewBeforeProcessing)
        let imageMode = defaults.bool(forKey: SettingsKey.imageModeDefault)
        for url in pdfs where !jobs.contains(where: { $0.sourceURL == url && !$0.status.isFinal }) {
            let meta = PDFAnalyzer.metadata(for: url)
            let job = BookJob(sourceURL: url, title: meta.title, author: meta.author, imageMode: imageMode)
            job.status = review ? .pendingReview : .queued
            jobs.append(job)
            Log.queue.info("Adicionado: \(url.lastPathComponent, privacy: .public)")
        }
        kick()
    }

    /// Só para `--snapshot`.
    func appendForPreview(_ job: BookJob) { jobs.append(job) }

    // MARK: - Controle

    func start(_ job: BookJob) {
        guard job.status == .pendingReview else { return }
        job.status = .queued
        kick()
    }

    func startAll() {
        jobs.filter { $0.status == .pendingReview }.forEach { $0.status = .queued }
        kick()
    }

    var hasPendingReview: Bool { jobs.contains { $0.status == .pendingReview } }
    var hasFinished: Bool { jobs.contains { $0.status.isFinal } }

    func cancel(_ job: BookJob) {
        if job.id == currentJobID {
            currentTask?.cancel()
        } else if !job.status.isFinal {
            job.status = .cancelled
            job.stage = .waiting
        }
    }

    func retry(_ job: BookJob) {
        guard job.status.isFinal else { return }
        job.resetForRetry()
        kick()
    }

    func remove(_ job: BookJob) {
        if job.id == currentJobID { currentTask?.cancel() }
        jobs.removeAll { $0.id == job.id }
    }

    func clearFinished() {
        jobs.removeAll { $0.status.isFinal }
    }

    func showInFinder(_ job: BookJob) {
        let url = job.outputURL ?? job.sourceURL
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    // MARK: - Worker

    private func kick() {
        guard worker == nil else { return }
        worker = Task { [weak self] in
            while let self, let job = self.nextJob() {
                await self.process(job)
            }
            self?.worker = nil
        }
    }

    private func nextJob() -> BookJob? {
        jobs.first { $0.status == .queued }
    }

    private func process(_ job: BookJob) async {
        job.status = .running
        currentJobID = job.id
        let config = PipelineConfig.current()
        let reporter = JobReporter(job: job)
        Log.queue.info("Iniciando: \(job.fileName, privacy: .public)")

        let task = Task.detached(priority: .userInitiated) {
            do {
                let message = try await BookPipeline(config: config).run(job, reporter: reporter)
                await MainActor.run {
                    job.stage = .finished
                    job.progress = 1
                    job.status = .succeeded(message)
                }
                Log.queue.info("Concluído: \(message, privacy: .public)")
            } catch is CancellationError {
                await MainActor.run { job.status = .cancelled }
                Log.queue.info("Cancelado")
            } catch {
                let message = error.localizedDescription
                await MainActor.run { job.status = .failed(message) }
                Log.queue.error("Falhou: \(message, privacy: .public)")
            }
        }
        currentTask = task
        await task.value
        currentTask = nil
        currentJobID = nil
    }
}
