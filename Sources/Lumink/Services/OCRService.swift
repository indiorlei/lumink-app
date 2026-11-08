import Foundation
import PDFKit

/// Decide quais páginas precisam de OCR, escolhe o motor e monta o PDF para conversão.
struct OCRService: Sendable {
    let config: PipelineConfig

    struct Outcome: Sendable {
        var pdf: URL
        var engine: String
        var recognizedChars: Int
        var ocrPages: Int
        /// Idioma detectado no texto reconhecido (ISO 639-1).
        var language: String?
    }

    /// `languages`: idiomas do Tesseract, já com o idioma do livro na frente (se conhecido).
    func run(pdf: URL, workDir: URL, languages: String, detail: @escaping @Sendable (String) async -> Void,
             progress: @escaping @Sendable (Double?) -> Void) async throws -> Outcome {
        let pages = Self.pagesNeedingOCR(pdf)
        guard !pages.isEmpty else { return Outcome(pdf: pdf, engine: "-", recognizedChars: 0, ocrPages: 0, language: nil) }
        Log.ocr.info("OCR em \(pages.count) páginas")

        var result: OCRResult
        var engineName: String
        let vision = VisionOCREngine(languages: OCRLanguages.visionCodes(from: languages))
        if !config.forceVisionOCR, let path = DependencyChecker.findOCRmyPDF(configured: config.ocrmypdfPath) {
            let engine = OCRmyPDFEngine(executable: path, languages: languages)
            await detail("ocrmypdf")
            do {
                result = try await engine.recognize(pdf: pdf, pages: pages, workDir: workDir, progress: progress)
                engineName = engine.name
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                Log.ocr.error("ocrmypdf falhou, usando Vision: \(error.localizedDescription, privacy: .public)")
                await detail(loc("ocrmypdf falhou → Vision", "ocrmypdf failed → Vision"))
                result = try await vision.recognize(pdf: pdf, pages: pages, workDir: workDir, progress: progress)
                engineName = loc("Vision (ocrmypdf falhou)", "Vision (ocrmypdf failed)")
            }
        } else {
            await detail("Vision")
            result = try await vision.recognize(pdf: pdf, pages: pages, workDir: workDir, progress: progress)
            engineName = vision.name
        }
        try Task.checkCancellation()

        let chars = result.values.reduce(0) { $0 + $1.reduce(0) { $0 + $1.text.count } }
        let recognized = result.keys.sorted().prefix(60)
            .flatMap { result[$0] ?? [] }.map(\.text).joined(separator: "\n")
        let output = workDir.appendingPathComponent("para-conversao.pdf")
        try TextLayerPDFBuilder.build(source: pdf, ocr: result, to: output)
        Log.ocr.info("OCR (\(engineName, privacy: .public)): \(chars) caracteres em \(pages.count) páginas")
        return Outcome(pdf: output, engine: engineName, recognizedChars: chars, ocrPages: pages.count,
                       language: BookLanguage.detect(recognized))
    }

    /// Todas as páginas (não só a amostra) com pouco ou nenhum texto.
    static func pagesNeedingOCR(_ url: URL) -> [Int] {
        guard let doc = PDFDocument(url: url) else { return [] }
        return (0..<doc.pageCount).filter { i in
            let chars = (doc.page(at: i)?.string ?? "").filter { !$0.isWhitespace }.count
            return chars < PDFAnalyzer.minCharsPerPage
        }
    }
}
