import Foundation
import PDFKit
import CoreGraphics

/// Modo imagem (HQ/mangá): uma imagem por página num EPUB3 de layout fixo.
/// As páginas são renderizadas em alta resolução; a etapa de compressão reduz depois.
struct ImageModeConverter: Sendable {
    static let renderHeight: CGFloat = 2400
    static let renderQuality = 0.9

    struct Options: Sendable {
        var title: String
        var author: String
        /// ISO 639-1, ex.: "pt", "en".
        var language: String
    }

    func convert(pdf: URL, to epub: URL, workDir: URL, options: Options,
                 progress: @escaping @Sendable (Double) -> Void) async throws {
        guard let doc = PDFDocument(url: pdf) else { throw PDFAnalyzerError.unreadable }
        let root = workDir.appendingPathComponent("fixed", isDirectory: true)
        let oebps = root.appendingPathComponent("OEBPS", isDirectory: true)
        let fm = FileManager.default
        for sub in ["META-INF", "OEBPS/images", "OEBPS/pages"] {
            try fm.createDirectory(at: root.appendingPathComponent(sub), withIntermediateDirectories: true)
        }

        var pages: [(id: String, width: Int, height: Int)] = []
        for i in 0..<doc.pageCount {
            try Task.checkCancellation()
            guard let page = doc.page(at: i) else { continue }
            let id = String(format: "p%04d", i + 1)
            let image = try autoreleasepool { try PDFPageRenderer.render(page, height: Self.renderHeight) }
            try ImageEncoder.writeJPEG(image, to: oebps.appendingPathComponent("images/\(id).jpg"), quality: Self.renderQuality)
            try Self.pageXHTML(id: id, number: i + 1, width: image.width, height: image.height, language: options.language)
                .write(to: oebps.appendingPathComponent("pages/\(id).xhtml"), atomically: true, encoding: .utf8)
            pages.append((id, image.width, image.height))
            progress(Double(i + 1) / Double(doc.pageCount) * 0.95)
        }
        guard let first = pages.first else { throw PDFAnalyzerError.empty }

        try Self.containerXML.write(to: root.appendingPathComponent("META-INF/container.xml"), atomically: true, encoding: .utf8)
        try Self.opf(pages: pages, options: options, resolution: (first.width, first.height))
            .write(to: oebps.appendingPathComponent("content.opf"), atomically: true, encoding: .utf8)
        try Self.nav(title: options.title, firstPage: first.id)
            .write(to: oebps.appendingPathComponent("nav.xhtml"), atomically: true, encoding: .utf8)
        try Self.ncx(title: options.title, firstPage: first.id)
            .write(to: oebps.appendingPathComponent("toc.ncx"), atomically: true, encoding: .utf8)
        try await EPUBArchive.zip(directory: root, to: epub)
        progress(1)
        Log.convert.info("Modo imagem: \(pages.count) páginas")
    }

    // MARK: - Arquivos do EPUB

    static func xmlEscape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    static let containerXML = """
    <?xml version="1.0" encoding="UTF-8"?>
    <container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
      <rootfiles><rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/></rootfiles>
    </container>
    """

    static func pageXHTML(id: String, number: Int, width: Int, height: Int, language: String) -> String {
        // Texto dentro do livro: segue o idioma do livro, não o do app.
        let label = "\(language == "pt" ? "Página" : "Page") \(number)"
        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE html>
        <html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops">
        <head>
          <title>\(label)</title>
          <meta name="viewport" content="width=\(width), height=\(height)"/>
          <style>html,body{margin:0;padding:0;width:\(width)px;height:\(height)px}img{width:\(width)px;height:\(height)px;display:block}</style>
        </head>
        <body><img src="../images/\(id).jpg" alt="\(label)"/></body>
        </html>
        """
    }

    static func opf(pages: [(id: String, width: Int, height: Int)], options: Options, resolution: (Int, Int)) -> String {
        let modified = ISO8601DateFormatter().string(from: Date())
        let creator = options.author.isEmpty ? "" : "<dc:creator>\(xmlEscape(options.author))</dc:creator>"
        let images = pages.enumerated().map { i, p in
            "<item id=\"img-\(p.id)\" href=\"images/\(p.id).jpg\" media-type=\"image/jpeg\"\(i == 0 ? " properties=\"cover-image\"" : "")/>"
        }.joined(separator: "\n    ")
        let docs = pages.map {
            "<item id=\"\($0.id)\" href=\"pages/\($0.id).xhtml\" media-type=\"application/xhtml+xml\"/>"
        }.joined(separator: "\n    ")
        let spine = pages.map { "<itemref idref=\"\($0.id)\"/>" }.joined(separator: "\n    ")
        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="bookid"
                 prefix="rendition: http://www.idpf.org/vocab/rendition/#">
          <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
            <dc:identifier id="bookid">urn:uuid:\(UUID().uuidString.lowercased())</dc:identifier>
            <dc:title>\(xmlEscape(options.title))</dc:title>
            \(creator)
            <dc:language>\(xmlEscape(options.language))</dc:language>
            <meta property="dcterms:modified">\(modified.prefix(19))Z</meta>
            <meta property="rendition:layout">pre-paginated</meta>
            <meta property="rendition:orientation">auto</meta>
            <meta property="rendition:spread">none</meta>
            <meta name="cover" content="img-\(pages[0].id)"/>
            <meta name="fixed-layout" content="true"/>
            <meta name="book-type" content="comic"/>
            <meta name="original-resolution" content="\(resolution.0)x\(resolution.1)"/>
          </metadata>
          <manifest>
            <item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>
            <item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>
            \(images)
            \(docs)
          </manifest>
          <spine toc="ncx">
            \(spine)
          </spine>
        </package>
        """
    }

    static func nav(title: String, firstPage: String) -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE html>
        <html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops">
        <head><title>\(xmlEscape(title))</title></head>
        <body><nav epub:type="toc"><ol><li><a href="pages/\(firstPage).xhtml">\(xmlEscape(title))</a></li></ol></nav></body>
        </html>
        """
    }

    static func ncx(title: String, firstPage: String) -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">
          <head><meta name="dtb:uid" content="lumink"/></head>
          <docTitle><text>\(xmlEscape(title))</text></docTitle>
          <navMap><navPoint id="n1" playOrder="1"><navLabel><text>\(xmlEscape(title))</text></navLabel>
            <content src="pages/\(firstPage).xhtml"/></navPoint></navMap>
        </ncx>
        """
    }
}
