import Foundation

enum PipelineStage: Int, CaseIterable, Sendable {
    case waiting, analyzing, ocr, converting, compressing, sending, finished

    var label: String {
        switch self {
        case .waiting: loc("Aguardando", "Waiting")
        case .analyzing: loc("Analisando", "Analyzing")
        case .ocr: "OCR"
        case .converting: loc("Convertendo", "Converting")
        case .compressing: loc("Comprimindo", "Compressing")
        case .sending: loc("Enviando", "Sending")
        case .finished: loc("Concluído", "Done")
        }
    }

    /// Etapas exibidas no indicador da linha.
    static let visible: [PipelineStage] = [.analyzing, .ocr, .converting, .compressing, .sending]
}

enum JobStatus: Equatable, Sendable {
    /// Aguardando o usuário revisar título/autor e clicar em "Processar".
    case pendingReview
    case queued
    case running
    case succeeded(String)
    case failed(String)
    case cancelled

    var isFinal: Bool {
        switch self {
        case .succeeded, .failed, .cancelled: true
        default: false
        }
    }
}
