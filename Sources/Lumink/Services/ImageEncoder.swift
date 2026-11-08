import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

enum ImageEncoder {
    enum EncodeError: Error { case failed(URL) }

    static func writeJPEG(_ image: CGImage, to url: URL, quality: Double) throws {
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw EncodeError.failed(url)
        }
        let props: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: quality]
        CGImageDestinationAddImage(dest, image, props as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { throw EncodeError.failed(url) }
    }

    static func writePNG(_ image: CGImage, to url: URL) throws {
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw EncodeError.failed(url)
        }
        CGImageDestinationAddImage(dest, image, nil)
        guard CGImageDestinationFinalize(dest) else { throw EncodeError.failed(url) }
    }
}
