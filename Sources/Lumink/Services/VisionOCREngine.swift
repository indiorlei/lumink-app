import Foundation
import PDFKit
import Vision

/// OCR com o framework Vision da Apple (alternativa quando não há ocrmypdf).
struct VisionOCREngine: OCREngine {
    let languages: [String]
    var name: String { "Vision" }

    /// ~300 dpi, limitado para não estourar memória em páginas grandes.
    private static let dpi: CGFloat = 300
    private static let maxHeight: CGFloat = 4000

    func recognize(pdf: URL, pages: [Int], workDir: URL,
                   progress: @escaping @Sendable (Double?) -> Void) async throws -> OCRResult {
        guard let doc = PDFDocument(url: pdf) else { throw PDFAnalyzerError.unreadable }
        var result = OCRResult()
        for (n, i) in pages.enumerated() {
            try Task.checkCancellation()
            guard let page = doc.page(at: i) else { continue }
            result[i] = try autoreleasepool { try recognize(page) }
            progress(Double(n + 1) / Double(pages.count))
        }
        return result
    }

    private func recognize(_ page: PDFPage) throws -> [OCRLine] {
        let size = PDFPageRenderer.displaySize(page)
        let height = min(size.height * Self.dpi / 72, Self.maxHeight)
        let image = try PDFPageRenderer.render(page, height: height, grayscale: true)

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = languages
        try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])

        let lines: [OCRLine] = (request.results ?? []).compactMap { obs in
            guard let candidate = obs.topCandidates(1).first else { return nil }
            let bb = obs.boundingBox // normalizado, origem embaixo à esquerda
            let rect = CGRect(x: bb.minX * size.width, y: bb.minY * size.height,
                              width: bb.width * size.width, height: bb.height * size.height)
            return OCRLine(text: candidate.string, rect: rect)
        }
        return Self.readingOrder(lines)
    }

    /// Vision não garante a ordem de leitura: de cima para baixo e, na mesma
    /// altura, da esquerda para a direita.
    static func readingOrder(_ lines: [OCRLine]) -> [OCRLine] {
        lines.sorted { a, b in
            let tolerance = min(a.rect.height, b.rect.height) * 0.5
            if abs(a.rect.midY - b.rect.midY) > tolerance { return a.rect.midY > b.rect.midY }
            return a.rect.minX < b.rect.minX
        }
    }
}
