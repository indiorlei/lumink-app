import Foundation

enum CompressionLevel: String, CaseIterable, Identifiable, Sendable {
    case high, medium, maximum

    var id: String { rawValue }

    var label: String {
        switch self {
        case .high: loc("Alta", "High")
        case .medium: loc("Média", "Medium")
        case .maximum: loc("Máxima compressão", "Maximum compression")
        }
    }

    var detail: String {
        loc("até \(maxHeight) px, JPEG \(Int(jpegQuality * 100))%",
            "up to \(maxHeight) px, JPEG \(Int(jpegQuality * 100))%")
    }

    /// Altura máxima das imagens, em pixels.
    var maxHeight: Int {
        switch self {
        case .high: 1600
        case .medium: 1600
        case .maximum: 1200
        }
    }

    var jpegQuality: Double {
        switch self {
        case .high: 0.85
        case .medium: 0.75
        case .maximum: 0.55
        }
    }

    /// Próximo nível mais agressivo (usado quando o arquivo passa do limite).
    var next: CompressionLevel? {
        switch self {
        case .high: .medium
        case .medium: .maximum
        case .maximum: nil
        }
    }
}
