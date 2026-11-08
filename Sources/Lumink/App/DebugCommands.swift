import AppKit
import SwiftUI

/// Modos de linha de comando para teste/depuração (o app normal ignora isto).
///
///   Lumink --process livro.pdf [outro.pdf] [--image-mode] [--vision] [--send] [--limit-mb N] [--cancel-after s]
///           [--via app|email] [--smtp host:porta --from a@b --to c@kindle.com --password x]
///   Lumink --keychain-test   grava, lê e apaga uma senha de teste no Keychain [--level high|medium|maximum]
///       Roda o pipeline no terminal e imprime o progresso. Sem --send, só gera o EPUB.
///   Lumink --compress entrada.epub saida.epub high|medium|maximum
///       Só a etapa de compressão.
///   Lumink --snapshot saida.png
///       Renderiza a janela principal (com itens de exemplo) num PNG.
///   Lumink --snapshot-notes saida.png
///       Renderiza a janela de novidades num PNG.
@MainActor
enum DebugCommands {
    static func handleIfNeeded() {
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "--snapshot-notes"), i + 1 < args.count {
            render(ReleaseNotesView(), size: NSSize(width: 520, height: 600), to: URL(fileURLWithPath: args[i + 1]))
            exit(0)
        }
        if let i = args.firstIndex(of: "--snapshot"), i + 1 < args.count {
            snapshot(to: URL(fileURLWithPath: args[i + 1]))
            exit(0)
        }
        if args.contains("--keychain-test") {
            let account = "lumink-selftest@example.com"
            do {
                try KeychainStore.setPassword("a\"b c\\d", for: account)
                let read1 = KeychainStore.password(for: account)
                try KeychainStore.setPassword("segunda", for: account)
                let read2 = KeychainStore.password(for: account)
                try KeychainStore.setPassword("", for: account)
                let read3 = KeychainStore.password(for: account)
                print("gravar/ler: \(read1 == "a\"b c\\d") · atualizar: \(read2 == "segunda") · apagar: \(read3 == nil)")
                exit(read1 == "a\"b c\\d" && read2 == "segunda" && read3 == nil ? 0 : 1)
            } catch { print("❌ \(error.localizedDescription)"); exit(1) }
        }
        if let i = args.firstIndex(of: "--compress"), i + 3 < args.count {
            let input = URL(fileURLWithPath: args[i + 1]), output = URL(fileURLWithPath: args[i + 2])
            let level = CompressionLevel(rawValue: args[i + 3]) ?? .medium
            Task<Void, Never> {
                do {
                let ws = try TempWorkspace()
                defer { ws.cleanup() }
                let stats = try await EPUBCompressor().compress(input, to: output, level: level, workDir: ws.url) { _ in }
                print("\(stats.images) imagens, \(stats.rewritten) reescritas, \(stats.converted) PNG→JPEG; \(Format.bytes(BookPipeline.fileSize(input))) → \(Format.bytes(BookPipeline.fileSize(output)))")
                exit(0)
                } catch { print("❌ \(error.localizedDescription)"); exit(1) }
            }
            dispatchMain()
        }
        if let i = args.firstIndex(of: "--process") {
            let files = args[(i + 1)...].prefix { !$0.hasPrefix("--") }.map { URL(fileURLWithPath: $0) }
            var config = PipelineConfig.current()
            config.onlyGenerate = !args.contains("--send")
            if let l = args.firstIndex(of: "--level"), l + 1 < args.count,
               let level = CompressionLevel(rawValue: args[l + 1]) {
                config.compression = level
            }
            config.forceVisionOCR = args.contains("--vision")
            func value(_ flag: String) -> String? {
                args.firstIndex(of: flag).flatMap { $0 + 1 < args.count ? args[$0 + 1] : nil }
            }
            if let via = value("--via") {   // app | email
                config.useSendToKindleApp = via == "app"
                config.useEmail = via == "email"
            }
            if let hp = value("--smtp") {
                config.useSendToKindleApp = false
                config.useEmail = true
                let parts = hp.split(separator: ":")
                config.smtp.host = String(parts[0])
                if parts.count > 1, let p = Int(parts[1]) { config.smtp.port = p }
            }
            if let v = value("--from") { config.smtp.sender = v }
            if let v = value("--to") { config.smtp.kindle = v }
            if let v = value("--password") { config.passwordOverride = v }
            if let l = args.firstIndex(of: "--limit-mb"), l + 1 < args.count, let mb = Double(args[l + 1]) {
                config.limitOverrideBytes = Int64(mb * 1_000_000)
            }
            let imageMode = args.contains("--image-mode")
            let cancelAfter = value("--cancel-after").flatMap(Double.init)
            Task { @MainActor in
                var failures = 0
                for file in files {
                    if await !process(file, config: config, imageMode: imageMode, cancelAfter: cancelAfter) { failures += 1 }
                }
                exit(failures == 0 ? 0 : 1)
            }
            dispatchMain()
        }
    }

    private static func process(_ url: URL, config: PipelineConfig, imageMode: Bool, cancelAfter: Double?) async -> Bool {
        let meta = PDFAnalyzer.metadata(for: url)
        let job = BookJob(sourceURL: url, title: meta.title, author: meta.author, imageMode: imageMode)
        job.status = .running
        print("▶︎ \(url.lastPathComponent) (\(Format.bytes(job.originalSize))) título=\"\(meta.title)\" autor=\"\(meta.author)\"")

        let printer = Task { @MainActor in
            var last = ""
            while !Task.isCancelled {
                let pct = job.progress.map { "\(Int($0 * 100))%" } ?? "…"
                let line = "  [\(job.stage.label)] \(pct) \(job.detail)"
                if line != last { print(line); last = line }
                try? await Task.sleep(for: .milliseconds(250))
            }
        }
        defer { printer.cancel() }

        let started = Date()
        let work = Task.detached { try await BookPipeline(config: config).run(job, reporter: JobReporter(job: job)) }
        if let cancelAfter {
            Task { try? await Task.sleep(for: .seconds(cancelAfter)); work.cancel(); print("  (cancelando…)") }
        }
        do {
            let msg = try await work.value
            try? await Task.sleep(for: .milliseconds(300))
            let elapsed = String(format: "%.1fs", Date().timeIntervalSince(started))
            print("✅ \(msg) [\(elapsed)]")
            if let out = job.outputURL { print("   → \(out.path) (\(Format.bytes(job.finalSize ?? 0)))") }
            return true
        } catch is CancellationError {
            print("⏹ Cancelado [\(String(format: "%.1fs", Date().timeIntervalSince(started)))]")
            return false
        } catch {
            print("❌ \(error.localizedDescription)")
            return false
        }
    }

    private static func snapshot(to url: URL) {
        let queue = QueueViewModel()
        let samples: [(String, JobStatus, PipelineStage, Double?, Int64?, String)] = [
            ("Dom Casmurro.pdf", .pendingReview, .waiting, 0, nil, ""),
            ("Sapiens - escaneado.pdf", .running, .ocr, nil, nil, "PDF escaneado · 412 páginas"),
            ("Manual Técnico.pdf", .running, .converting, 0.42, nil, "PDF com texto · 220 páginas"),
            ("Mangá vol 1.pdf", .succeeded("Enviado para nome@kindle.com"), .finished, 1, 31_400_000, "Modo imagem · Média"),
            ("Enorme.pdf", .failed("O EPUB ficou com 63 MB mesmo na compressão máxima (limite: 50 MB). Não foi enviado."), .finished, 1, 63_000_000, ""),
        ]
        for (name, status, stage, progress, final, detail) in samples {
            let job = BookJob(sourceURL: URL(fileURLWithPath: "/tmp/\(name)"),
                              title: (name as NSString).deletingPathExtension, author: "Autor Exemplo", imageMode: false)
            job.status = status
            job.stage = stage
            job.progress = progress
            job.finalSize = final
            job.detail = detail
            if final != nil { job.outputURL = URL(fileURLWithPath: "/tmp/x.epub") }
            queue.appendForPreview(job)
        }
        render(MainView().environment(queue), size: NSSize(width: 760, height: 640), to: url)
    }

    private static func render(_ view: some View, size: NSSize, to url: URL) {
        let hosting = NSHostingView(rootView: view.frame(width: size.width, height: size.height)
            .background(Color(nsColor: .windowBackgroundColor)))
        hosting.frame = NSRect(origin: .zero, size: size)
        let window = NSWindow(contentRect: hosting.frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = hosting
        hosting.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.5))
        guard let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else { return }
        hosting.cacheDisplay(in: hosting.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: url)
        print("snapshot: \(url.path)")
    }
}
