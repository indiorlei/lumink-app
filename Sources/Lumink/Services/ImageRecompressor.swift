import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

/// Recomprime uma imagem do EPUB com ImageIO/CoreGraphics.
/// - Redimensiona para no máximo `level.maxHeight` px de altura.
/// - JPEG reencodado com a qualidade do nível.
/// - PNG sem transparência real e "grande" vira JPEG.
/// Só substitui o arquivo se o resultado ficar menor.
struct ImageRecompressor: Sendable {
    let level: CompressionLevel

    /// Abaixo disso não vale a pena mexer (ícones, ornamentos).
    static let minBytes: Int64 = 12_000
    /// PNGs opacos acima disso viram JPEG.
    static let pngToJPEGMinBytes: Int64 = 40_000

    enum Outcome: Equatable {
        case unchanged
        case rewritten(saved: Int64)
        /// PNG convertido em JPEG: o arquivo mudou de nome.
        case converted(to: URL, saved: Int64)
    }

    func process(_ url: URL) -> Outcome {
        do {
            return try processOrThrow(url)
        } catch {
            Log.compress.error("Imagem ignorada \(url.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return .unchanged
        }
    }

    private func processOrThrow(_ url: URL) throws -> Outcome {
        let originalBytes = Self.size(of: url)
        guard originalBytes >= Self.minBytes,
              let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let type = CGImageSourceGetType(source).map({ UTType($0 as String) }) ?? nil,
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = props[kCGImagePropertyPixelWidth] as? Int,
              let height = props[kCGImagePropertyPixelHeight] as? Int
        else { return .unchanged }

        let isJPEG = type.conforms(to: .jpeg)
        let isPNG = type.conforms(to: .png)
        guard isJPEG || isPNG else { return .unchanged }

        let needsResize = height > level.maxHeight
        let targetMaxSide: Int = {
            guard needsResize else { return max(width, height) }
            let scale = Double(level.maxHeight) / Double(height)
            return Int((Double(max(width, height)) * scale).rounded())
        }()
        guard let image = Self.decode(source, maxSide: targetMaxSide) else { return .unchanged }

        let tmp = url.deletingLastPathComponent().appendingPathComponent(".kp-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tmp) }

        if isJPEG {
            try ImageEncoder.writeJPEG(image, to: tmp, quality: level.jpegQuality)
            return try replaceIfSmaller(url, with: tmp, original: originalBytes)
        }

        // PNG
        let hasAlpha = (props[kCGImagePropertyHasAlpha] as? Bool) ?? false
        let opaque = !hasAlpha || Self.isFullyOpaque(image)
        if opaque && (originalBytes >= Self.pngToJPEGMinBytes || needsResize) {
            try ImageEncoder.writeJPEG(Self.flattened(image), to: tmp, quality: level.jpegQuality)
            let newBytes = Self.size(of: tmp)
            if newBytes < originalBytes {
                let target = Self.jpegName(for: url)
                try FileManager.default.moveItem(at: tmp, to: target)
                try FileManager.default.removeItem(at: url)
                return .converted(to: target, saved: originalBytes - newBytes)
            }
            // JPEG não ajudou (ex.: scan em tons de cinza): tenta só redimensionar o PNG.
        }
        guard needsResize else { return .unchanged }
        try ImageEncoder.writePNG(image, to: tmp)
        return try replaceIfSmaller(url, with: tmp, original: originalBytes)
    }

    private func replaceIfSmaller(_ url: URL, with tmp: URL, original: Int64) throws -> Outcome {
        let newBytes = Self.size(of: tmp)
        guard newBytes > 0, newBytes < original else { return .unchanged }
        _ = try FileManager.default.replaceItemAt(url, withItemAt: tmp)
        return .rewritten(saved: original - newBytes)
    }

    // MARK: - Utilidades

    static func size(of url: URL) -> Int64 {
        ((try? FileManager.default.attributesOfItem(atPath: url.path))?[.size] as? NSNumber)?.int64Value ?? 0
    }

    /// Decodifica já redimensionado (thumbnail do ImageIO é rápido e respeita a orientação EXIF).
    static func decode(_ source: CGImageSource, maxSide: Int) -> CGImage? {
        let opts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxSide,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, opts as CFDictionary)
    }

    /// Verifica pixel a pixel: muitos PNGs têm canal alfa, mas tudo 100% opaco.
    static func isFullyOpaque(_ image: CGImage) -> Bool {
        let w = image.width, h = image.height
        var data = [UInt8](repeating: 0, count: w * h * 4)
        let ok: Bool = data.withUnsafeMutableBytes { buf in
            guard let ctx = CGContext(data: buf.baseAddress, width: w, height: h, bitsPerComponent: 8,
                                      bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        guard ok else { return false }
        var i = 3
        while i < data.count {
            if data[i] < 255 { return false }
            i += 4
        }
        return true
    }

    /// Remove o canal alfa (fundo branco) para o encoder JPEG.
    static func flattened(_ image: CGImage) -> CGImage {
        guard image.alphaInfo != .none, image.alphaInfo != .noneSkipLast, image.alphaInfo != .noneSkipFirst,
              let ctx = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8,
                                  bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
        else { return image }
        let rect = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        ctx.setFillColor(.white)
        ctx.fill(rect)
        ctx.draw(image, in: rect)
        return ctx.makeImage() ?? image
    }

    static func jpegName(for png: URL) -> URL {
        let dir = png.deletingLastPathComponent()
        let base = png.deletingPathExtension().lastPathComponent
        let simple = dir.appendingPathComponent("\(base).jpg")
        if !FileManager.default.fileExists(atPath: simple.path) { return simple }
        return dir.appendingPathComponent("\(base)-kp.jpg")
    }
}
