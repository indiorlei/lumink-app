import Foundation

/// Novidades mostradas no app (janela "Novidades do Lumink").
/// Texto para quem usa o app; o histórico técnico fica no CHANGELOG.md.
/// A versão mais nova vem primeiro e deve bater com CFBundleShortVersionString.
struct ReleaseNote: Identifiable, Sendable {
    struct Section: Sendable {
        var title: String
        var items: [String]
    }

    var version: String
    var date: String
    var headline: String
    var sections: [Section]
    var id: String { version }
}

enum ReleaseNotes {
    static let all: [ReleaseNote] = [
        ReleaseNote(
            version: "1.0",
            date: "8 de novembro de 2026",
            headline: "Primeira versão",
            sections: [
                .init(title: "Bem-vindo ao Lumink", items: [
                    "Converta, comprima e envie seus PDFs para o leitor digital em um só gesto.",
                    "O nome junta *lume* (luz, chama) e *ink* (tinta). Em inglês, *kindle* quer dizer acender: o lume é essa chama, e a tinta é onde ela acende.",
                ]),
                .init(title: "Do PDF ao Kindle", items: [
                    "Arraste PDFs para a janela ou para o ícone do Dock. Eles entram numa fila e são processados um de cada vez.",
                    "Confira título e autor antes de processar, ou desligue a revisão nas Configurações.",
                    "Use *Só gerar* para salvar o EPUB sem enviar.",
                ]),
                .init(title: "Livros escaneados e HQs", items: [
                    "O OCR reconhece português e inglês, e o EPUB se ajusta à tela do Kindle.",
                    "O Modo imagem gera um EPUB de página fixa para HQs e mangás. Liga sozinho quando o PDF quase não tem texto.",
                ]),
                .init(title: "Tamanho e envio", items: [
                    "Três níveis de compressão (Alta, Média e Máxima). Se o livro passar do limite, o app tenta o nível seguinte.",
                    "Envio por e-mail para o Send to Kindle, com a senha guardada só no Keychain.",
                    "Botão de e-mail de teste para validar a configuração sem gastar um documento.",
                ]),
                .init(title: "Novidades", items: [
                    "Esta janela fica em Lumink → Novidades do Lumink… e aparece sozinha quando sai uma versão nova.",
                ]),
            ]
        ),
    ]

    static var current: ReleaseNote { all[0] }

    private static let lastSeenKey = "lastSeenReleaseNotes"

    /// Verdadeiro uma vez por versão; marca como vista ao consultar.
    static func consumeShouldShowOnLaunch() -> Bool {
        let defaults = UserDefaults.standard
        guard defaults.string(forKey: lastSeenKey) != current.version else { return false }
        defaults.set(current.version, forKey: lastSeenKey)
        return true
    }
}
