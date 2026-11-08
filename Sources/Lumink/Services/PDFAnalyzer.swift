import Foundation
import PDFKit

enum PDFKind: String, Sendable {
    case text, scanned, mixed

    var label: String {
        switch self {
        case .text: "PDF com texto"
        case .scanned: "PDF escaneado"
        case .mixed: "PDF misto"
        }
    }
}

struct PDFAnalysis: Sendable {
    var kind: PDFKind
    var pageCount: Int
    var sampledPages: Int
    var pagesWithText: Int
}

struct PDFMetadata: Sendable {
    var title: String
    var author: String
}

enum PDFAnalyzerError: LocalizedError {
    case unreadable, encrypted, empty

    var errorDescription: String? {
        switch self {
        case .unreadable: "Não foi possível abrir o PDF."
        case .encrypted: "O PDF está protegido por senha."
        case .empty: "O PDF não tem páginas."
        }
    }
}

enum PDFAnalyzer {
    /// Mínimo de caracteres para considerar que a página "tem texto".
    static let minCharsPerPage = 40
    static let maxSample = 30

    static func metadata(for url: URL) -> PDFMetadata {
        let fallback = url.deletingPathExtension().lastPathComponent
        guard let doc = PDFDocument(url: url) else { return PDFMetadata(title: fallback, author: "") }
        let attrs = doc.documentAttributes ?? [:]
        let title = (attrs[PDFDocumentAttribute.titleAttribute] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let author = (attrs[PDFDocumentAttribute.authorAttribute] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return PDFMetadata(
            title: (title?.isEmpty == false && !looksLikeJunkTitle(title!)) ? title! : fallback,
            author: author ?? ""
        )
    }

    /// Títulos como "Microsoft Word - doc1.docx" ou "untitled" não ajudam.
    private static func looksLikeJunkTitle(_ t: String) -> Bool {
        let l = t.lowercased()
        return l.hasPrefix("microsoft word") || l == "untitled" || l.hasSuffix(".doc")
            || l.hasSuffix(".docx") || l.hasSuffix(".pdf") || l.hasSuffix(".indd")
    }

    static func analyze(_ url: URL) throws -> PDFAnalysis {
        guard let doc = PDFDocument(url: url) else { throw PDFAnalyzerError.unreadable }
        if doc.isLocked { throw PDFAnalyzerError.encrypted }
        let count = doc.pageCount
        guard count > 0 else { throw PDFAnalyzerError.empty }

        let indices = sampleIndices(pageCount: count)
        var withText = 0
        for i in indices {
            guard let page = doc.page(at: i) else { continue }
            let chars = (page.string ?? "").filter { !$0.isWhitespace }.count
            if chars >= minCharsPerPage { withText += 1 }
        }
        let ratio = Double(withText) / Double(indices.count)
        let kind: PDFKind =
            ratio >= 0.9 ? .text :
            ratio < 0.5 ? .scanned : .mixed
        Log.analyze.info("\(url.lastPathComponent, privacy: .public): \(withText)/\(indices.count) páginas com texto → \(kind.rawValue, privacy: .public)")
        return PDFAnalysis(kind: kind, pageCount: count, sampledPages: indices.count, pagesWithText: withText)
    }

    /// Amostra espalhada pelo livro (ignora capa quando possível).
    static func sampleIndices(pageCount: Int) -> [Int] {
        if pageCount <= maxSample { return Array(0..<pageCount) }
        let step = Double(pageCount) / Double(maxSample)
        return (0..<maxSample).map { min(pageCount - 1, Int(Double($0) * step + step / 2)) }
    }
}
