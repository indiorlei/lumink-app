import Foundation

/// Chaves do UserDefaults (usadas com @AppStorage nas views).
/// A senha NÃO fica aqui: vai para o Keychain (`KeychainStore`).
enum SettingsKey {
    static let calibrePath = "calibrePath"
    static let ocrmypdfPath = "ocrmypdfPath"
    static let ocrLanguages = "ocrLanguages"
    static let kindleEmail = "kindleEmail"
    static let senderEmail = "senderEmail"
    static let smtpHost = "smtpHost"
    static let smtpPort = "smtpPort"
    static let compressionLevel = "compressionLevel"
    static let onlyGenerate = "onlyGenerate"
    static let reviewBeforeProcessing = "reviewBeforeProcessing"
    static let imageModeDefault = "imageModeDefault"
    static let maxAttachmentMB = "maxAttachmentMB"
    static let useSendToKindleApp = "useSendToKindleApp"
    static let useEmail = "useEmail"
}

enum SettingsDefault {
    static let calibrePath = "/Applications/calibre.app/Contents/MacOS/ebook-convert"
    static let ocrmypdfPath = "" // vazio = procurar automaticamente
    static let ocrLanguages = "por+eng"
    static let smtpHost = "smtp.gmail.com"
    static let smtpPort = 465
    static let compressionLevel = CompressionLevel.medium.rawValue
    static let maxAttachmentMB = 50

    static func register() {
        let d = UserDefaults.standard
        // Quem já tinha configurado o SMTP antes desta opção existir continua com o e-mail ligado.
        if d.object(forKey: SettingsKey.useEmail) == nil,
           !(d.string(forKey: SettingsKey.senderEmail) ?? "").isEmpty {
            d.set(true, forKey: SettingsKey.useEmail)
        }
        d.register(defaults: [
            SettingsKey.calibrePath: calibrePath,
            SettingsKey.ocrmypdfPath: ocrmypdfPath,
            SettingsKey.ocrLanguages: ocrLanguages,
            SettingsKey.smtpHost: smtpHost,
            SettingsKey.smtpPort: smtpPort,
            SettingsKey.compressionLevel: compressionLevel,
            SettingsKey.onlyGenerate: false,
            SettingsKey.reviewBeforeProcessing: true,
            SettingsKey.imageModeDefault: false,
            SettingsKey.maxAttachmentMB: maxAttachmentMB,
            SettingsKey.useSendToKindleApp: true,
            SettingsKey.useEmail: false,
        ])
    }
}

/// Retrato imutável das configurações, passado ao pipeline no início de cada job.
struct PipelineConfig: Sendable {
    var calibrePath: String
    var ocrmypdfPath: String
    var ocrLanguages: String
    var compression: CompressionLevel
    var onlyGenerate: Bool
    var useSendToKindleApp: Bool
    var useEmail: Bool
    var smtp: SMTPConfig
    var maxAttachmentBytes: Int64
    /// Só para testes (`--vision`): ignora o ocrmypdf.
    var forceVisionOCR = false
    /// Só para testes (`--limit-mb`): aplica este limite mesmo sem enviar.
    var limitOverrideBytes: Int64?
    /// Só para testes (`--password`): não lê o Keychain.
    var passwordOverride: String?

    static func current() -> PipelineConfig {
        SettingsDefault.register()
        let d = UserDefaults.standard
        return PipelineConfig(
            calibrePath: d.string(forKey: SettingsKey.calibrePath) ?? SettingsDefault.calibrePath,
            ocrmypdfPath: d.string(forKey: SettingsKey.ocrmypdfPath) ?? "",
            ocrLanguages: d.string(forKey: SettingsKey.ocrLanguages) ?? SettingsDefault.ocrLanguages,
            compression: CompressionLevel(rawValue: d.string(forKey: SettingsKey.compressionLevel) ?? "") ?? .medium,
            onlyGenerate: d.bool(forKey: SettingsKey.onlyGenerate),
            useSendToKindleApp: d.bool(forKey: SettingsKey.useSendToKindleApp),
            useEmail: d.bool(forKey: SettingsKey.useEmail),
            smtp: SMTPConfig.current(),
            maxAttachmentBytes: Int64(max(1, d.integer(forKey: SettingsKey.maxAttachmentMB))) * 1_000_000
        )
    }

    /// Limite efetivo: o do Kindle (50 MB) ou o do provedor SMTP, o que for menor.
    /// O Gmail recusa mensagens acima de 25 MB; com base64 (+33%), sobram ~18 MB de anexo.
    var effectiveLimitBytes: Int64 {
        if let provider = smtp.providerAttachmentLimitBytes {
            return min(maxAttachmentBytes, provider)
        }
        return maxAttachmentBytes
    }
}

struct SMTPConfig: Sendable {
    var host: String
    var port: Int
    var sender: String
    var kindle: String

    static func current() -> SMTPConfig {
        SettingsDefault.register()
        let d = UserDefaults.standard
        return SMTPConfig(
            host: (d.string(forKey: SettingsKey.smtpHost) ?? SettingsDefault.smtpHost)
                .trimmingCharacters(in: .whitespaces),
            port: d.integer(forKey: SettingsKey.smtpPort),
            sender: (d.string(forKey: SettingsKey.senderEmail) ?? "").trimmingCharacters(in: .whitespaces),
            kindle: (d.string(forKey: SettingsKey.kindleEmail) ?? "").trimmingCharacters(in: .whitespaces)
        )
    }

    var providerAttachmentLimitBytes: Int64? {
        let h = host.lowercased()
        if h.hasSuffix("gmail.com") || h.hasSuffix("googlemail.com") { return 18_000_000 }
        return nil
    }
}
