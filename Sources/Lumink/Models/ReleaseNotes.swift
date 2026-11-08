import Foundation

/// Novidades mostradas no app (janela "Novidades do Lumink"), em português e inglês.
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
            version: "1.1",
            date: loc("8 de novembro de 2026", "November 8, 2026"),
            headline: loc("Envio sem senha e o Lumink em inglês", "Password-free delivery, and Lumink in English"),
            sections: [
                .init(title: loc("Envio pelo app da Amazon", "Delivery through Amazon's app"), items: [
                    loc("O Lumink agora abre o EPUB no app oficial *Send to Kindle* da Amazon, e você confirma o envio por lá. O login fica com a Amazon: nenhuma senha passa pelo Lumink.",
                        "Lumink now opens the EPUB in Amazon's official *Send to Kindle* app, and you confirm the delivery there. The login stays with Amazon: no password goes through Lumink."),
                    loc("O e-mail continua disponível em Configurações → Envio. Com os dois ligados, o app tem prioridade e o e-mail entra quando o app não está instalado.",
                        "Email is still available in Settings → Delivery. With both on, the app comes first and email takes over when the app isn't installed."),
                ]),
                .init(title: loc("O idioma certo no Kindle", "The right language on your Kindle"), items: [
                    loc("O Lumink detecta o idioma do livro e grava no EPUB. O Kindle usa esse idioma para o dicionário, a hifenização e a leitura em voz alta.",
                        "Lumink detects the book's language and writes it into the EPUB. The Kindle uses it for the dictionary, hyphenation and text-to-speech."),
                    loc("Antes, todo livro saía marcado como português, mesmo em inglês.",
                        "Before, every book was tagged as Portuguese, even English ones."),
                    loc("Na revisão de título e autor, o menu *Idioma* deixa você trocar.",
                        "In the title and author review, the *Language* menu lets you change it."),
                ]),
                .init(title: loc("Lumink em inglês", "Lumink in English"), items: [
                    loc("O app segue o idioma do macOS: português ou inglês. Para escolher só para o Lumink: Ajustes do Sistema → Geral → Idioma e Região → Aplicativos.",
                        "The app follows your macOS language: English or Portuguese. To pick one just for Lumink: System Settings → General → Language & Region → Applications."),
                ]),
            ]
        ),
        ReleaseNote(
            version: "1.0",
            date: loc("8 de novembro de 2026", "November 8, 2026"),
            headline: loc("Primeira versão", "First release"),
            sections: [
                .init(title: loc("Bem-vindo ao Lumink", "Welcome to Lumink"), items: [
                    loc("Converta, comprima e envie seus PDFs para o leitor digital em um só gesto.",
                        "Convert, compress and send your PDFs to your e-reader in a single gesture."),
                    loc("O nome junta *lume* (luz, chama) e *ink* (tinta). Em inglês, *kindle* quer dizer acender: o lume é essa chama, e a tinta é onde ela acende.",
                        "The name joins *lume* (Portuguese for light, flame) and *ink*. And to *kindle* means to set alight: the lume is that flame, and the ink is where it catches."),
                ]),
                .init(title: loc("Do PDF ao Kindle", "From PDF to Kindle"), items: [
                    loc("Arraste PDFs para a janela ou para o ícone do Dock. Eles entram numa fila e são processados um de cada vez.",
                        "Drag PDFs into the window or onto the Dock icon. They go into a queue and are processed one at a time."),
                    loc("Confira título e autor antes de processar, ou desligue a revisão nas Configurações.",
                        "Check the title and author before processing, or turn the review off in Settings."),
                    loc("Use *Só gerar* para salvar o EPUB sem enviar.",
                        "Use *Only generate* to save the EPUB without sending it."),
                ]),
                .init(title: loc("Livros escaneados e HQs", "Scanned books and comics"), items: [
                    loc("O OCR reconhece português e inglês, e o EPUB se ajusta à tela do Kindle.",
                        "OCR recognizes Portuguese and English, and the EPUB adapts to the Kindle screen."),
                    loc("O Modo imagem gera um EPUB de página fixa para HQs e mangás. Liga sozinho quando o PDF quase não tem texto.",
                        "Image mode builds a fixed-layout EPUB for comics and manga. It turns on by itself when the PDF has almost no text."),
                ]),
                .init(title: loc("Tamanho e envio", "Size and delivery"), items: [
                    loc("Três níveis de compressão (Alta, Média e Máxima). Se o livro passar do limite, o app tenta o nível seguinte.",
                        "Three compression levels (High, Medium and Maximum). If the book is over the limit, the app tries the next level."),
                    loc("Envio por e-mail para o Send to Kindle, com a senha guardada só no Keychain.",
                        "Delivery by email to Send to Kindle, with the password stored only in the Keychain."),
                    loc("Botão de e-mail de teste para validar a configuração sem gastar um documento.",
                        "A test email button to check the setup without using up a document."),
                ]),
                .init(title: loc("Novidades", "What's new"), items: [
                    loc("Esta janela fica em Lumink → Novidades do Lumink… e aparece sozinha quando sai uma versão nova.",
                        "This window lives in Lumink → What's New in Lumink… and opens by itself when a new version comes out."),
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
