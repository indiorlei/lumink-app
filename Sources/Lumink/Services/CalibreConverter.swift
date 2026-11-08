import Foundation

/// PDF → EPUB com o `ebook-convert` do Calibre, otimizado para reflow de livros.
struct CalibreConverter: Sendable {
    let executable: String

    struct Options: Sendable {
        var title: String
        var author: String
        /// ISO 639-1, ex.: "pt", "en".
        var language: String
    }

    func convert(pdf: URL, to epub: URL, options: Options,
                 progress: @escaping @Sendable (Double) -> Void) async throws {
        var args = [
            pdf.path, epub.path,
            "--output-profile", "kindle_pw3",
            // Motor do calibre: detecta e remove cabeçalhos/rodapés repetidos.
            "--pdf-engine", "calibre",
            "--pdf-header-skip", "-1",
            "--pdf-footer-skip", "-1",
            // Números de página soltos no rodapé.
            "--pdf-footer-regex", #"^\s*[-–—]?\s*\d{1,4}\s*[-–—]?\s*$"#,
            "--unwrap-factor", "0.45",
            // Heurísticas: junta linhas quebradas, remove hifenização, detecta capítulos.
            "--enable-heuristics",
            "--smarten-punctuation",
            "--remove-paragraph-spacing",
            "--remove-paragraph-spacing-indent-size", "1.5",
            // Kindle aplica a própria fonte/margens.
            "--filter-css", "font-family,color,background-color",
            "--epub-version", "3",
            "--chapter-mark", "pagebreak",
            "--title", options.title,
            "--language", options.language,
        ]
        if !options.author.trimmingCharacters(in: .whitespaces).isEmpty {
            args += ["--authors", options.author]
        }
        Log.convert.info("Convertendo \(pdf.lastPathComponent, privacy: .public)")
        try await ProcessRunner.runChecked(executable, args, tool: "ebook-convert") { line in
            // Linhas como "34% Running transforms on e-book..."
            if let pct = Self.parsePercent(line) { progress(pct) }
            Log.convert.debug("\(line, privacy: .public)")
        }
        guard FileManager.default.fileExists(atPath: epub.path) else {
            throw ProcessError.failed(tool: "ebook-convert", code: 0, tail: "Nenhum EPUB foi gerado.")
        }
    }

    static func parsePercent(_ line: String) -> Double? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard let pctIndex = trimmed.firstIndex(of: "%") else { return nil }
        let number = trimmed[..<pctIndex]
        guard !number.isEmpty, number.count <= 3, let v = Double(number) else { return nil }
        return v / 100
    }
}
