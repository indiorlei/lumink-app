import Foundation
import PDFKit
import CoreGraphics

enum PDFPageRenderer {
    enum RenderError: LocalizedError {
        case failed(Int)
        var errorDescription: String? {
            if case .failed(let p) = self { return loc("Falha ao renderizar a página \(p + 1).", "Failed to render page \(p + 1).") }
            return nil
        }
    }

    /// Tamanho visível da página (considerando rotação), em pontos.
    static func displaySize(_ page: PDFPage) -> CGSize {
        let box = page.bounds(for: .mediaBox)
        return page.rotation % 180 != 0 ? CGSize(width: box.height, height: box.width) : box.size
    }

    /// Renderiza a página com a altura indicada (em pixels), fundo branco.
    static func render(_ page: PDFPage, height: CGFloat, grayscale: Bool = false) throws -> CGImage {
        let size = displaySize(page)
        let scale = height / size.height
        let w = max(1, Int((size.width * scale).rounded())), h = max(1, Int(height.rounded()))
        let space = grayscale ? CGColorSpaceCreateDeviceGray() : CGColorSpace(name: CGColorSpace.sRGB)!
        let info = grayscale ? CGImageAlphaInfo.none.rawValue : CGImageAlphaInfo.noneSkipLast.rawValue
        let index = page.document?.index(for: page) ?? 0
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: space, bitmapInfo: info) else { throw RenderError.failed(index) }
        ctx.setFillColor(gray: 1, alpha: 1)
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        ctx.interpolationQuality = .high
        ctx.scaleBy(x: scale, y: scale)
        page.draw(with: .mediaBox, to: ctx)
        guard let image = ctx.makeImage() else { throw RenderError.failed(index) }
        return image
    }
}
