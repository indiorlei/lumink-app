import Foundation
import CoreGraphics

/// Uma linha reconhecida, em pontos, relativa ao canto inferior esquerdo do mediaBox.
struct OCRLine: Sendable {
    var text: String
    var rect: CGRect
}

/// Resultado do OCR: índice da página → linhas.
typealias OCRResult = [Int: [OCRLine]]

protocol OCREngine: Sendable {
    var name: String { get }
    func recognize(pdf: URL, pages: [Int], workDir: URL,
                   progress: @escaping @Sendable (Double?) -> Void) async throws -> OCRResult
}

enum OCRLanguages {
    /// Código do Tesseract → (ISO 639-1, código do Vision).
    private static let table: [(tesseract: String, iso: String, vision: String)] = [
        ("por", "pt", "pt-BR"), ("eng", "en", "en-US"), ("spa", "es", "es-ES"),
        ("fra", "fr", "fr-FR"), ("deu", "de", "de-DE"), ("ita", "it", "it-IT"),
        ("jpn", "ja", "ja-JP"), ("chi_sim", "zh", "zh-Hans"), ("kor", "ko", "ko-KR"),
        ("rus", "ru", "ru-RU"),
    ]

    private static func codes(_ tesseract: String) -> [String] {
        tesseract.split(separator: "+").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    /// "por+eng" (Tesseract) → ["pt-BR", "en-US"] (Vision).
    static func visionCodes(from tesseract: String) -> [String] {
        let vision = codes(tesseract).compactMap { code in table.first { $0.tesseract == code }?.vision }
        return vision.isEmpty ? ["pt-BR", "en-US"] : vision
    }

    /// Põe o idioma do livro (ISO 639-1) na frente da lista, acrescentando-o se faltar.
    /// O Vision dá prioridade ao primeiro idioma; o Tesseract também pesa a ordem.
    static func prioritizing(_ iso: String?, in tesseract: String) -> String {
        guard let iso, let entry = table.first(where: { $0.iso == iso }) else { return tesseract }
        let rest = codes(tesseract).filter { $0 != entry.tesseract }
        return ([entry.tesseract] + rest).joined(separator: "+")
    }
}
