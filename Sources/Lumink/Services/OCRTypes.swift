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
    /// "por+eng" (Tesseract) → ["pt-BR", "en-US"] (Vision).
    static func visionCodes(from tesseract: String) -> [String] {
        let map = ["por": "pt-BR", "eng": "en-US", "spa": "es-ES", "fra": "fr-FR",
                   "deu": "de-DE", "ita": "it-IT", "jpn": "ja-JP", "chi_sim": "zh-Hans",
                   "kor": "ko-KR", "rus": "ru-RU"]
        let codes = tesseract.split(separator: "+").compactMap { map[String($0).trimmingCharacters(in: .whitespaces)] }
        return codes.isEmpty ? ["pt-BR", "en-US"] : codes
    }
}
