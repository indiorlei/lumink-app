// Gera PDFs de teste em TestData/:
//   texto.pdf      – texto real, cabeçalho repetido, nº de página, uma foto grande
//   escaneado.pdf  – páginas só com imagem (sem camada de texto)
//   misto.pdf      – alterna páginas de texto e páginas escaneadas
// Uso: swift Scripts/make-test-pdfs.swift
import Foundation
import CoreGraphics
import CoreText
import ImageIO
import UniformTypeIdentifiers

let outDir = URL(fileURLWithPath: "TestData", isDirectory: true)
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

let pageRect = CGRect(x: 0, y: 0, width: 420, height: 595) // A5 em pontos
let paragraphs = [
    "Capítulo %d",
    "Era uma vez uma pequena cidade à beira de um rio, onde as manhãs começavam com o cheiro de pão quente e o som dos sinos da igreja. Ninguém ali tinha pressa, e os dias passavam devagar, como se o tempo também gostasse de descansar.",
    "Joana acordava cedo, abria a janela e observava os barcos que desciam o rio carregados de frutas. Ela sonhava em viajar, conhecer outras terras e escrever sobre tudo o que visse. Seu avô dizia que as melhores histórias são aquelas que a gente vive antes de contar.",
    "Naquela manhã, porém, algo diferente aconteceu: um barco sem tripulantes encostou no cais. Dentro dele havia apenas uma caixa de madeira, fechada com um cadeado antigo, e um bilhete escrito à mão com uma letra elegante e apressada.",
    "The quick brown fox jumps over the lazy dog. Este parágrafo mistura idiomas para testar o OCR em português e inglês, com acentuação: ação, coração, pão, avó, café, você.",
]

func pageText(_ n: Int) -> String {
    let chapter = (n - 1) / 3 + 1
    // Título do capítulo só na primeira página de cada capítulo (como num livro real).
    var parts = (n - 1) % 3 == 0 ? [String(format: paragraphs[0], chapter)] : []
    parts += paragraphs[1...].shuffledDeterministic(seed: n)
    return parts.joined(separator: "\n\n")
}

extension ArraySlice where Element == String {
    func shuffledDeterministic(seed: Int) -> [String] {
        let arr = Array(self)
        return arr.indices.map { arr[($0 + seed) % arr.count] }
    }
}

/// Desenha cabeçalho, corpo e número de página num contexto (PDF ou bitmap).
func drawTextPage(_ ctx: CGContext, number: Int, rect: CGRect) {
    let margin: CGFloat = 36
    func draw(_ s: String, size: CGFloat, in frame: CGRect, bold: Bool = false, center: Bool = false) {
        let font = CTFontCreateWithName((bold ? "Georgia-Bold" : "Georgia") as CFString, size, nil)
        var align: CTTextAlignment = center ? .center : .justified
        let style = withUnsafeBytes(of: &align) { ptr in
            [CTParagraphStyleSetting(spec: .alignment, valueSize: MemoryLayout<CTTextAlignment>.size, value: ptr.baseAddress!)]
        }
        let para = CTParagraphStyleCreate(style, style.count)
        let attr = NSAttributedString(string: s, attributes: [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTParagraphStyleAttributeName as String): para,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(gray: 0, alpha: 1),
        ])
        let fs = CTFramesetterCreateWithAttributedString(attr)
        let path = CGPath(rect: frame, transform: nil)
        CTFrameDraw(CTFramesetterCreateFrame(fs, CFRange(location: 0, length: 0), path, nil), ctx)
    }
    let w = rect.width, h = rect.height
    draw("O Barco Sem Nome — Livro de Teste", size: 8, in: CGRect(x: margin, y: h - 30, width: w - 2 * margin, height: 14), center: true)
    draw(pageText(number), size: 11, in: CGRect(x: margin, y: 50, width: w - 2 * margin, height: h - 100))
    draw("\(number)", size: 9, in: CGRect(x: margin, y: 20, width: w - 2 * margin, height: 14), center: true)
}

/// Página "escaneada": renderiza o texto num bitmap cinza levemente torto e com ruído.
func scannedImage(number: Int, dpi: CGFloat = 200) -> CGImage {
    let scale = dpi / 72
    let W = Int(pageRect.width * scale), H = Int(pageRect.height * scale)
    let ctx = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)!
    ctx.setFillColor(gray: 0.96, alpha: 1)
    ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))
    ctx.scaleBy(x: scale, y: scale)
    ctx.translateBy(x: pageRect.midX, y: pageRect.midY)
    ctx.rotate(by: 0.004)
    ctx.translateBy(x: -pageRect.midX, y: -pageRect.midY)
    drawTextPage(ctx, number: number, rect: pageRect)
    // ruído leve
    var rng = SystemRandomNumberGenerator()
    ctx.setFillColor(gray: 0.6, alpha: 0.5)
    for _ in 0..<400 {
        ctx.fill(CGRect(x: CGFloat.random(in: 0...pageRect.width, using: &rng),
                        y: CGFloat.random(in: 0...pageRect.height, using: &rng), width: 0.4, height: 0.4))
    }
    return ctx.makeImage()!
}

/// Foto sintética grande (3000x4000) codificada em JPEG q95, para testar a compressão.
func bigPhoto() -> CGImage {
    let W = 3000, H = 4000
    let ctx = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    let colors = [CGColor(red: 0.1, green: 0.3, blue: 0.7, alpha: 1), CGColor(red: 0.9, green: 0.6, blue: 0.2, alpha: 1)] as CFArray
    let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: nil)!
    ctx.drawLinearGradient(grad, start: .zero, end: CGPoint(x: W, y: H), options: [])
    for i in 0..<300 {
        let x = CGFloat((i * 7919) % W), y = CGFloat((i * 104729) % H), r = CGFloat(20 + (i * 31) % 180)
        ctx.setFillColor(red: CGFloat(i % 7) / 7, green: CGFloat(i % 5) / 5, blue: CGFloat(i % 3) / 3, alpha: 0.6)
        ctx.fillEllipse(in: CGRect(x: x, y: y, width: r, height: r))
    }
    // reencoda como JPEG para o PDF embutir DCT
    let data = NSMutableData()
    let dest = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, ctx.makeImage()!, [kCGImageDestinationLossyCompressionQuality: 0.95] as CFDictionary)
    CGImageDestinationFinalize(dest)
    let src = CGImageSourceCreateWithData(data, nil)!
    return CGImageSourceCreateImageAtIndex(src, 0, nil)!
}

func makePDF(_ name: String, pages: Int, title: String, scanned: (Int) -> Bool, photoOnPage: Int? = nil) {
    let url = outDir.appendingPathComponent(name)
    var box = pageRect
    let info: [CFString: Any] = [kCGPDFContextTitle: title, kCGPDFContextAuthor: "Autora de Teste", kCGPDFContextCreator: "make-test-pdfs"]
    let ctx = CGContext(url as CFURL, mediaBox: &box, info as CFDictionary)!
    for n in 1...pages {
        ctx.beginPDFPage(nil)
        if scanned(n) {
            ctx.draw(scannedImage(number: n), in: pageRect)
        } else if n == photoOnPage {
            ctx.draw(bigPhoto(), in: pageRect.insetBy(dx: 30, dy: 60))
        } else {
            drawTextPage(ctx, number: n, rect: pageRect)
        }
        ctx.endPDFPage()
    }
    ctx.closePDF()
    let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
    print("✓ \(url.path) (\(pages) páginas, \(size / 1024) KB)")
}

makePDF("texto.pdf", pages: 12, title: "O Barco Sem Nome", scanned: { _ in false }, photoOnPage: 4)
makePDF("escaneado.pdf", pages: 6, title: "", scanned: { _ in true })
makePDF("misto.pdf", pages: 8, title: "Livro Misto", scanned: { $0 % 2 == 0 })
