import Foundation

/// Orquestra as etapas de um job. Roda fora do MainActor.
struct BookPipeline: Sendable {
    let config: PipelineConfig

    /// Retorna a mensagem de sucesso, ou lança erro.
    func run(_ job: BookJob, reporter: JobReporter) async throws -> String {
        let source = await MainActor.run { job.sourceURL }
        let workspace = try TempWorkspace()
        defer { workspace.cleanup() }

        // 1. Análise
        await reporter.stage(.analyzing)
        let analysis = try PDFAnalyzer.analyze(source)
        var meta = await reporter.snapshot()
        var baseDetail = "\(analysis.kind.label) · \(Format.pages(analysis.pageCount))"
        // Idioma do livro: o escolhido na revisão, senão o detectado no texto do PDF.
        // Em PDFs escaneados, sai do texto do OCR, mais abaixo.
        var language = meta.language ?? analysis.language
        if let language { baseDetail += " · \(BookLanguage.name(language))" }
        await reporter.detail(baseDetail)
        try Task.checkCancellation()

        // 2. OCR (escaneado ou misto, fora do modo imagem)
        var pdfForConversion = source
        if !meta.imageMode && analysis.kind != .text {
            await reporter.stage(.ocr)
            let ocrDetail = baseDetail
            let outcome = try await OCRService(config: config).run(
                pdf: source, workDir: workspace.url,
                languages: OCRLanguages.prioritizing(language, in: config.ocrLanguages),
                detail: { await reporter.detail("\(ocrDetail) · OCR: \($0)") },
                progress: { reporter.progress($0, in: .ocr) }
            )
            pdfForConversion = outcome.pdf
            if language == nil, let detected = outcome.language {
                language = detected
                baseDetail += " · \(BookLanguage.name(detected))"
            }
            await reporter.detail("\(baseDetail) · OCR: \(outcome.engine)")
            // Quase nada reconhecido (HQ, mangá, fotos): o reflow daria um livro vazio.
            if outcome.ocrPages > 0 && outcome.recognizedChars / outcome.ocrPages < 100 && analysis.kind == .scanned {
                Log.ocr.info("Pouco texto reconhecido; mudando para o modo imagem")
                meta.imageMode = true
                await MainActor.run { job.imageMode = true }
                baseDetail += loc(" · pouco texto → Modo imagem", " · little text → Image mode")
                await reporter.detail(baseDetail)
            }
            try Task.checkCancellation()
        } else if meta.imageMode {
            baseDetail += loc(" · Modo imagem", " · Image mode")
            await reporter.detail(baseDetail)
        }

        // 3. Conversão
        // Sem texto para detectar (HQ, mangá), vale o idioma da interface.
        let bookLanguage = language ?? BookLanguage.fallback
        await reporter.stage(.converting)
        let epub = workspace.file("convertido.epub")
        if meta.imageMode {
            try await ImageModeConverter().convert(
                pdf: source, to: epub, workDir: workspace.url,
                options: .init(title: meta.title, author: meta.author, language: bookLanguage)
            ) { reporter.progress($0, in: .converting) }
        } else {
            guard let calibre = DependencyChecker.findCalibre(configured: config.calibrePath) else {
                throw PipelineError.calibreMissing
            }
            try await CalibreConverter(executable: calibre).convert(
                pdf: pdfForConversion, to: epub,
                options: .init(title: meta.title, author: meta.author, language: bookLanguage)
            ) { reporter.progress($0, in: .converting) }
        }
        try Task.checkCancellation()

        // 4. Compressão (com fallback de nível se passar do limite de anexo)
        await reporter.stage(.compressing)
        // A forma de envio define o limite de tamanho. Se nenhuma servir, o EPUB
        // ainda é gerado e salvo; o erro só aparece na etapa de envio.
        let delivery: Result<Delivery, Error>? = config.onlyGenerate ? nil : Result { try resolveDelivery() }
        let limit: Int64? = config.limitOverrideBytes ?? delivery.map {
            switch $0 {
            case .success(.app): SendToKindleApp.limitBytes
            case .success(.email), .failure: config.effectiveLimitBytes
            }
        }
        var level = config.compression
        var final: URL
        var finalSize: Int64
        while true {
            await reporter.detail("\(baseDetail) · \(level.label)")
            final = workspace.file("final-\(level.rawValue).epub")
            _ = try await EPUBCompressor().compress(epub, to: final, level: level, workDir: workspace.url) {
                reporter.progress($0, in: .compressing)
            }
            finalSize = Self.fileSize(final)
            Log.compress.info("Tamanho com \(level.rawValue, privacy: .public): \(finalSize)")
            guard let limit, finalSize > limit, let next = level.next else { break }
            Log.compress.info("Acima do limite (\(limit)); tentando \(next.rawValue, privacy: .public)")
            level = next
            await reporter.stage(.compressing)
        }
        try Task.checkCancellation()

        // Salva em ~/Documents/Lumink
        let output = try OutputLocation.uniqueURL(forTitle: meta.title)
        try FileManager.default.moveItem(at: final, to: output)
        let savedSize = finalSize
        await MainActor.run {
            job.outputURL = output
            job.finalSize = savedSize
        }
        let levelNote = level == config.compression ? "" : PipelineMessage.compressionRaised(to: level)

        if let limit, finalSize > limit {
            throw PipelineError.tooLarge(size: finalSize, limit: limit)
        }
        // 5. Envio
        guard let delivery else { return PipelineMessage.saved(output.lastPathComponent) + levelNote }
        await reporter.stage(.sending)
        switch try delivery.get() {
        case .app(let app):
            try await SendToKindleApp.open(output, with: app)
            reporter.progress(1, in: .sending)
            return PipelineMessage.openedInSendToKindle + levelNote
        case .email(let sender):
            let message = MailComposer.build(
                from: config.smtp.sender, to: config.smtp.kindle, subject: meta.title,
                body: loc("Enviado pelo Lumink: ", "Sent by Lumink: ")
                    + meta.title + (meta.author.isEmpty ? "" : " — \(meta.author)"),
                attachment: .init(filename: OutputLocation.sanitize(meta.title) + ".epub", mimeType: "application/epub+zip",
                                  data: try Data(contentsOf: output))
            )
            let messageFile = workspace.file("mensagem.eml")
            try message.write(to: messageFile)
            try await sender.send(messageFile: messageFile) { reporter.progress($0, in: .sending) }
            return PipelineMessage.sent(to: config.smtp.kindle) + levelNote
        }
    }

    enum Delivery {
        case app(URL)
        case email(MailSender)
    }

    /// App oficial, se ligado e instalado; senão o e-mail, se ligado e configurado.
    func resolveDelivery() throws -> Delivery {
        if config.useSendToKindleApp, let app = SendToKindleApp.locate() { return .app(app) }
        if config.useEmail {
            return .email(try MailSender.configured(config.smtp, passwordOverride: config.passwordOverride))
        }
        throw config.useSendToKindleApp ? PipelineError.sendToKindleMissing : PipelineError.noDelivery
    }

    static func fileSize(_ url: URL) -> Int64 {
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        return (attrs?[.size] as? NSNumber)?.int64Value ?? 0
    }
}

/// Mensagens de sucesso, também usadas pela prévia do `--snapshot`.
enum PipelineMessage {
    static func saved(_ fileName: String) -> String {
        loc("EPUB salvo em \(fileName)", "EPUB saved as \(fileName)")
    }

    static var openedInSendToKindle: String {
        loc("Aberto no Send to Kindle: confirme o envio na janela do app",
            "Opened in Send to Kindle: confirm the delivery in the app's window")
    }

    static func sent(to email: String) -> String {
        loc("Enviado para \(email)", "Sent to \(email)")
    }

    static func compressionRaised(to level: CompressionLevel) -> String {
        loc(" (compressão aumentada para \(level.label))", " (compression raised to \(level.label))")
    }
}

enum PipelineError: LocalizedError {
    case calibreMissing
    case tooLarge(size: Int64, limit: Int64)
    case sendToKindleMissing
    case noDelivery

    var errorDescription: String? {
        switch self {
        case .calibreMissing:
            loc("Calibre não encontrado. Instale em calibre-ebook.com (ou `brew install --cask calibre`) e confira o caminho em Configurações → Conversão. PDFs de HQ/mangá funcionam sem ele no Modo imagem.",
                "Calibre not found. Install it from calibre-ebook.com (or `brew install --cask calibre`) and check the path in Settings → Conversion. Comic and manga PDFs work without it in Image mode.")
        case .tooLarge(let size, let limit):
            loc("O EPUB ficou com \(Format.bytes(size)) mesmo na compressão máxima (limite: \(Format.bytes(limit))). Ele foi salvo, mas não foi enviado.",
                "The EPUB is \(Format.bytes(size)) even at maximum compression (limit: \(Format.bytes(limit))). It was saved, but not sent.")
        case .sendToKindleMissing:
            loc("App Send to Kindle não encontrado. O EPUB foi salvo; baixe o app em \(SendToKindleApp.downloadURL.absoluteString) ou ligue o envio por e-mail em Configurações (⌘,).",
                "Send to Kindle app not found. The EPUB was saved; download the app at \(SendToKindleApp.downloadURL.absoluteString) or turn on email delivery in Settings (⌘,).")
        case .noDelivery:
            loc("Nenhuma forma de envio ligada. O EPUB foi salvo; ligue o app Send to Kindle ou o e-mail em Configurações (⌘,).",
                "No delivery method is on. The EPUB was saved; turn on the Send to Kindle app or email in Settings (⌘,).")
        }
    }
}
