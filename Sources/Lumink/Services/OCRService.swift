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
    }

    func run(pdf: URL, workDir: URL, detail: @escaping @Sendable (String) async -> Void,
             progress: @escaping @Sendable (Double?) -> Void) async throws -> Outcome {
        let pages = Self.pagesNeedingOCR(pdf)
        guard !pages.isEmpty else { return Outcome(pdf: pdf, engine: "-", recognizedChars: 0, ocrPages: 0) }
        Log.ocr.info("OCR em \(pages.count) páginas")

        var result: OCRResult
        var engineName: String
        let vision = VisionOCREngine(languages: OCRLanguages.visionCodes(from: config.ocrLanguages))
        if !config.forceVisionOCR, let path = DependencyChecker.findOCRmyPDF(configured: config.ocrmypdfPath) {
            let engine = OCRmyPDFEngine(executable: path, languages: config.ocrLanguages)
            await detail("ocrmypdf")
            do {
                result = try await engine.recognize(pdf: pdf, pages: pages, workDir: workDir, progress: progress)
                engineName = engine.name
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                Log.ocr.error("ocrmypdf falhou, usando Vision: \(error.localizedDescription, privacy: .public)")
                await detail("ocrmypdf falhou → Vision")
                result = try await vision.recognize(pdf: pdf, pages: pages, workDir: workDir, progress: progress)
                engineName = "Vision (ocrmypdf falhou)"
            }
        } else {
            await detail("Vision")
            result = try await vision.recognize(pdf: pdf, pages: pages, workDir: workDir, progress: progress)
            engineName = vision.name
        }
        try Task.checkCancellation()

        let chars = result.values.reduce(0) { $0 + $1.reduce(0) { $0 + $1.text.count } }
        let output = workDir.appendingPathComponent("para-conversao.pdf")
        try TextLayerPDFBuilder.build(source: pdf, ocr: result, to: output)
        Log.ocr.info("OCR (\(engineName, privacy: .public)): \(chars) caracteres em \(pages.count) páginas")
        return Outcome(pdf: output, engine: engineName, recognizedChars: chars, ocrPages: pages.count)
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
