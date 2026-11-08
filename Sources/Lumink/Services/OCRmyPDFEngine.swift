import Foundation
import PDFKit

/// OCR com o `ocrmypdf` (Tesseract). Depois lê a camada de texto gerada, linha a linha.
struct OCRmyPDFEngine: OCREngine {
    let executable: String
    let languages: String
    var name: String { "ocrmypdf" }

    func recognize(pdf: URL, pages: [Int], workDir: URL,
                   progress: @escaping @Sendable (Double?) -> Void) async throws -> OCRResult {
        let output = workDir.appendingPathComponent("ocrmypdf.pdf")
        let total = Double(max(1, PDFDocument(url: pdf)?.pageCount ?? 1))
        let seen = PageCounter()
        let args = [
            "--skip-text",                 // não refaz páginas que já têm texto
            "-l", languages,
            "--output-type", "pdf",        // sem PDF/A: mais rápido
            "--optimize", "0",
            "--jobs", String(max(1, ProcessInfo.processInfo.activeProcessorCount - 1)),
            "-v", "1",
            pdf.path, output.path,
        ]
        progress(0)
        try await ProcessRunner.runChecked(executable, args, tool: "ocrmypdf") { line in
            // Linhas por página começam com o número da página: "    3 ..."
            if let n = Self.leadingPageNumber(line) {
                progress(Double(seen.insert(n)) / total * 0.95)
            }
            Log.ocr.debug("\(line, privacy: .public)")
        }
        return try Self.extractLines(from: output, pages: pages)
    }

    static func leadingPageNumber(_ line: String) -> Int? {
        let trimmed = line.drop { $0 == " " }
        guard trimmed.count < line.count else { return nil } // exige recuo
        let digits = trimmed.prefix { $0.isNumber }
        guard !digits.isEmpty, trimmed.dropFirst(digits.count).first == " " else { return nil }
        return Int(digits)
    }

    static func extractLines(from pdf: URL, pages: [Int]) throws -> OCRResult {
        guard let doc = PDFDocument(url: pdf) else { throw PDFAnalyzerError.unreadable }
        var result = OCRResult()
        for i in pages {
            guard let page = doc.page(at: i) else { continue }
            let box = page.bounds(for: .mediaBox)
            let lines = page.selection(for: box)?.selectionsByLine() ?? []
            result[i] = lines.compactMap { sel in
                guard let text = sel.string?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
                let r = sel.bounds(for: page)
                return OCRLine(text: text, rect: r.offsetBy(dx: -box.minX, dy: -box.minY))
            }
        }
        return result
    }
}

private final class PageCounter: @unchecked Sendable {
    private var pages = Set<Int>()
    private let lock = NSLock()
    func insert(_ n: Int) -> Int {
        lock.lock(); defer { lock.unlock() }
        pages.insert(n)
        return pages.count
    }
}
