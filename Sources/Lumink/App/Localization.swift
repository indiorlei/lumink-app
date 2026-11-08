import Foundation

/// O app fala português e inglês e segue o idioma do macOS (ou o escolhido para o
/// Lumink em Ajustes do Sistema → Geral → Idioma e Região → Aplicativos).
/// Qualquer outro idioma cai no inglês.
///
/// Os textos ficam lado a lado no código, `loc("português", "English")`, em vez de
/// arquivos .strings: assim nenhum texto novo nasce sem a tradução, e o build com
/// `swiftc` continua sem precisar do Xcode.
enum AppLanguage {
    static let isPortuguese: Bool = {
        // `-AppleLanguages (en)` na linha de comando também vale (útil no `--snapshot`).
        let preferred = Bundle.main.preferredLocalizations.first ?? "en"
        return preferred.hasPrefix("pt")
    }()

    /// Locale do idioma da interface, para nomes de idiomas e datas.
    static var locale: Locale { Locale(identifier: isPortuguese ? "pt_BR" : "en_US") }

    /// Código ISO 639-1 do idioma da interface.
    static var code: String { isPortuguese ? "pt" : "en" }
}

/// Texto da interface no idioma do app.
func loc(_ portuguese: String, _ english: String) -> String {
    AppLanguage.isPortuguese ? portuguese : english
}
