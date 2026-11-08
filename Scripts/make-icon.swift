// Gera o ícone do Lumink: uma chama (o lume) sobre um traço de tinta, em fundo azul-tinta.
//
// Uso (de qualquer pasta):  swift app/Scripts/make-icon.swift
// Saída:
//   app/Resources/AppIcon.icns                 ícone do app (16 a 1024 px)
//   app/Resources/AppIcon.png                  1024 px, para referência
//   site/src/app/favicon.ico                   16, 32 e 48 px
//   site/src/app/icon.png, apple-icon.png      512 e 180 px
import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent()   // app/Scripts
    .deletingLastPathComponent().deletingLastPathComponent()              // raiz do repositório
let appResources = repo.appendingPathComponent("app/Resources")
let siteApp = repo.appendingPathComponent("site/src/app")

let S: CGFloat = 1024
let cs = CGColorSpace(name: CGColorSpace.sRGB)!

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}

func gradient(_ colors: [CGColor], _ locs: [CGFloat]? = nil) -> CGGradient {
    CGGradient(colorsSpace: cs, colors: colors as CFArray, locations: locs)!
}

/// Placa 824×824 centrada, como na grade de ícones do macOS.
let plate = CGPath(roundedRect: CGRect(x: 100, y: 100, width: 824, height: 824),
                   cornerWidth: 185, cornerHeight: 185, transform: nil)

/// Chama em coordenadas unitárias (0…1, y para cima), mapeada para `r`.
func flame(in r: CGRect) -> CGPath {
    func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: r.minX + x * r.width, y: r.minY + y * r.height) }
    let path = CGMutablePath()
    path.move(to: p(0.5, 0))
    path.addCurve(to: p(0.0, 0.38), control1: p(0.18, 0), control2: p(0.0, 0.17))
    path.addCurve(to: p(0.56, 1.0), control1: p(0.0, 0.68), control2: p(0.42, 0.78))
    path.addCurve(to: p(1.0, 0.38), control1: p(0.72, 0.74), control2: p(1.0, 0.64))
    path.addCurve(to: p(0.5, 0), control1: p(1.0, 0.17), control2: p(0.82, 0))
    path.closeSubpath()
    return path
}

func fill(_ ctx: CGContext, _ path: CGPath, _ g: CGGradient, from a: CGPoint, to b: CGPoint) {
    ctx.saveGState(); ctx.addPath(path); ctx.clip()
    ctx.drawLinearGradient(g, start: a, end: b, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    ctx.restoreGState()
}

func drawIcon(_ ctx: CGContext) {
    // Fundo azul-tinta.
    fill(ctx, plate, gradient([rgb(0x1F2A44), rgb(0x0E1424)]), from: CGPoint(x: 0, y: 924), to: CGPoint(x: 0, y: 100))
    // Brilho quente atrás da chama.
    ctx.saveGState(); ctx.addPath(plate); ctx.clip()
    let c = CGPoint(x: 512, y: 420)
    ctx.drawRadialGradient(gradient([rgb(0xF59F00, 0.28), rgb(0xF59F00, 0)]), startCenter: c, startRadius: 0,
                           endCenter: c, endRadius: 420, options: [])
    ctx.restoreGState()
    // Chama: camada externa laranja→amarelo e núcleo claro.
    let r = CGRect(x: 322, y: 210, width: 380, height: 600)
    fill(ctx, flame(in: r), gradient([rgb(0xE8590C), rgb(0xF59F00), rgb(0xFFD43B)], [0, 0.55, 1]),
         from: CGPoint(x: r.midX, y: r.maxY), to: CGPoint(x: r.midX, y: r.minY))
    let core = CGRect(x: r.minX + r.width * 0.27, y: r.minY + r.height * 0.04, width: r.width * 0.46, height: r.height * 0.55)
    fill(ctx, flame(in: core), gradient([rgb(0xFFF3BF), rgb(0xFFFBEA)]),
         from: CGPoint(x: core.midX, y: core.maxY), to: CGPoint(x: core.midX, y: core.minY))
    // Traço de tinta na base.
    ctx.setStrokeColor(rgb(0xFBF6EA, 0.9)); ctx.setLineWidth(16); ctx.setLineCap(.round)
    ctx.move(to: CGPoint(x: 250, y: 190))
    ctx.addCurve(to: CGPoint(x: 774, y: 190), control1: CGPoint(x: 420, y: 150), control2: CGPoint(x: 600, y: 230))
    ctx.strokePath()
}

func render(_ px: Int) -> CGImage {
    let ctx = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0,
                        space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.interpolationQuality = .high
    ctx.scaleBy(x: CGFloat(px) / S, y: CGFloat(px) / S)
    drawIcon(ctx)
    return ctx.makeImage()!
}

func pngData(_ img: CGImage) -> Data {
    let data = NSMutableData()
    let dest = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, img, nil); CGImageDestinationFinalize(dest)
    return data as Data
}

func write(_ data: Data, _ url: URL) throws {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try data.write(to: url)
    print("✓ \(url.path.replacingOccurrences(of: repo.path + "/", with: ""))")
}

// .icns via iconset + iconutil.
let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("Lumink-\(UUID().uuidString).iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: iconset) }
for base in [16, 32, 128, 256, 512] {
    try pngData(render(base)).write(to: iconset.appendingPathComponent("icon_\(base)x\(base).png"))
    try pngData(render(base * 2)).write(to: iconset.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
let icns = appResources.appendingPathComponent("AppIcon.icns")
let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", icns.path]
try iconutil.run(); iconutil.waitUntilExit()
guard iconutil.terminationStatus == 0 else { fatalError("iconutil falhou") }
print("✓ app/Resources/AppIcon.icns")
try write(pngData(render(1024)), appResources.appendingPathComponent("AppIcon.png"))

// favicon.ico: cabeçalho ICO com PNGs embutidos (aceito por todos os navegadores atuais).
let icoSizes = [16, 32, 48]
let icoImages = icoSizes.map { pngData(render($0)) }
var ico = Data()
func le16(_ v: Int) { ico.append(contentsOf: [UInt8(v & 0xFF), UInt8((v >> 8) & 0xFF)]) }
func le32(_ v: Int) { for i in 0..<4 { ico.append(UInt8((v >> (8 * i)) & 0xFF)) } }
le16(0); le16(1); le16(icoSizes.count)
var offset = 6 + 16 * icoSizes.count
for (size, png) in zip(icoSizes, icoImages) {
    ico.append(UInt8(size)); ico.append(UInt8(size)); ico.append(0); ico.append(0)
    le16(1); le16(32); le32(png.count); le32(offset)
    offset += png.count
}
icoImages.forEach { ico.append($0) }
try write(ico, siteApp.appendingPathComponent("favicon.ico"))
try write(pngData(render(512)), siteApp.appendingPathComponent("icon.png"))
try write(pngData(render(180)), siteApp.appendingPathComponent("apple-icon.png"))
