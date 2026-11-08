import Foundation
import PDFKit
import CoreText

/// Monta o PDF que vai para o Calibre: páginas com texto ficam como estão; páginas
/// escaneadas viram texto VISÍVEL nas mesmas posições, sem a imagem.
///
/// Motivo: o Calibre (ambos os motores) ignora texto invisível (render mode 3),
/// que é como o ocrmypdf/Tesseract grava a camada de OCR. Além disso, sem a
/// imagem da página, o EPUB não carrega um "scan" inteiro por página.
enum TextLayerPDFBuilder {
    static func build(source: URL, ocr: OCRResult, to output: URL) throws {
        guard let doc = PDFDocument(url: source) else { throw PDFAnalyzerError.unreadable }
        guard let ctx = CGContext(output as CFURL, mediaBox: nil, nil) else { throw PDFAnalyzerError.unreadable }
        for i in 0..<doc.pageCount {
            guard let page = doc.page(at: i) else { continue }
            if let lines = ocr[i] {
                var box = CGRect(origin: .zero, size: page.bounds(for: .mediaBox).size)
                ctx.beginPage(mediaBox: &box)
                lines.forEach { draw($0, in: ctx) }
                ctx.endPage()
            } else {
                var box = CGRect(origin: .zero, size: PDFPageRenderer.displaySize(page))
                ctx.beginPage(mediaBox: &box)
                page.draw(with: .mediaBox, to: ctx)
                ctx.endPage()
            }
        }
        ctx.closePDF()
    }

    private static func draw(_ line: OCRLine, in ctx: CGContext) {
        let rect = line.rect
        guard rect.height > 1, rect.width > 1 else { return }
        // A caixa inclui ascendentes e descendentes; ~75% dela é o corpo da fonte.
        let fontSize = max(4, rect.height * 0.75)
        let font = CTFontCreateWithName("Times New Roman" as CFString, fontSize, nil)
        let attr = NSAttributedString(string: line.text, attributes: [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(gray: 0, alpha: 1),
        ])
        let ctLine = CTLineCreateWithAttributedString(attr)
        var descent: CGFloat = 0
        let width = CGFloat(CTLineGetTypographicBounds(ctLine, nil, &descent, nil))
        guard width > 0 else { return }
        // Estica/encolhe na horizontal para ocupar a largura original (ajuda o
        // Calibre a decidir onde juntar linhas de um mesmo parágrafo).
        let sx = min(max(rect.width / width, 0.5), 2)
        ctx.saveGState()
        ctx.textMatrix = CGAffineTransform(scaleX: sx, y: 1)
        ctx.textPosition = CGPoint(x: rect.minX, y: rect.minY + descent)
        CTLineDraw(ctLine, ctx)
        ctx.restoreGState()
    }
}
