import Foundation
import NaturalLanguage

/// Idioma do livro, que vai para os metadados do EPUB (`dc:language`). O Kindle usa
/// esse idioma para escolher o dicionário, a hifenização e a voz da leitura em voz alta.
enum BookLanguage {
    /// Opções da revisão de título e autor (ISO 639-1).
    static let choices = ["pt", "en", "es", "fr", "de", "it"]

    /// Mínimo de letras para confiar na detecção.
    private static let minLetters = 200

    /// Detecta o idioma de uma amostra de texto. `nil` se houver pouco texto ou dúvida.
    static func detect(_ text: String) -> String? {
        let sample = String(text.prefix(20_000))
        guard sample.unicodeScalars.filter(CharacterSet.letters.contains).count >= minLetters else { return nil }
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(sample)
        guard let (language, confidence) = recognizer.languageHypotheses(withMaximum: 1).first,
              confidence >= 0.6 else { return nil }
        // "zh-Hans" → "zh": o EPUB e o Calibre usam o código base.
        return Locale.Language(identifier: language.rawValue).languageCode?.identifier ?? language.rawValue
    }

    /// Quando não há texto para detectar (HQ, mangá): português, o idioma do app.
    static let fallback = "pt"

    private static let locale = Locale(identifier: "pt_BR")

    /// Nome do idioma em português: "inglês".
    static func name(_ code: String) -> String {
        locale.localizedString(forLanguageCode: code) ?? code
    }

    /// Nome para menus, com inicial maiúscula: "Inglês".
    static func menuName(_ code: String) -> String {
        name(code).capitalized(with: locale)
    }
}
