import Foundation

/// Envia via `curl` (já vem no macOS): SMTPS na porta 465, STARTTLS nas outras.
/// A senha vai pelo stdin (`-K -`), nunca na linha de comando (visível no `ps`) nem em arquivo.
struct MailSender: Sendable {
    static let curl = "/usr/bin/curl"

    let smtp: SMTPConfig
    let password: String

    enum MailError: LocalizedError {
        case notConfigured(String)
        case curl(code: Int32, detail: String)

        var errorDescription: String? {
            switch self {
            case .notConfigured(let what):
                "E-mail não configurado: \(what). Abra Configurações (⌘,) → Kindle e e-mail."
            case .curl(let code, let detail):
                "\(Self.explain(code)) (curl \(code))\n\(detail.suffix(400))"
            }
        }

        static func explain(_ code: Int32) -> String {
            switch code {
            case 6: "Servidor SMTP não encontrado. Confira o endereço."
            case 7: "Não foi possível conectar ao servidor SMTP. Confira servidor, porta e a internet."
            case 28: "Tempo esgotado ao falar com o servidor SMTP."
            case 35, 60: "Falha na conexão segura (TLS) com o servidor."
            case 55: "O servidor recusou a mensagem (talvez seja grande demais)."
            case 67: "Login recusado. No Gmail, use uma senha de app (não a senha normal da conta)."
            default: "Falha ao enviar o e-mail."
            }
        }
    }

    /// Lê a senha do Keychain e valida a configuração.
    static func configured(_ smtp: SMTPConfig, passwordOverride: String? = nil) throws -> MailSender {
        if smtp.kindle.isEmpty { throw MailError.notConfigured("falta o e-mail do Kindle") }
        if smtp.sender.isEmpty { throw MailError.notConfigured("falta o e-mail remetente") }
        if smtp.host.isEmpty { throw MailError.notConfigured("falta o servidor SMTP") }
        guard let password = passwordOverride ?? KeychainStore.password(for: smtp.sender), !password.isEmpty else {
            throw MailError.notConfigured("falta a senha de app (salve no Keychain)")
        }
        return MailSender(smtp: smtp, password: password)
    }

    var isLocalRelay: Bool { ["localhost", "127.0.0.1", "::1"].contains(smtp.host.lowercased()) }

    func send(messageFile: URL, progress: (@Sendable (Double) -> Void)? = nil) async throws {
        let port = smtp.port > 0 ? smtp.port : 465
        let scheme = port == 465 ? "smtps" : "smtp"
        var args = [
            "--url", "\(scheme)://\(smtp.host):\(port)/localhost",   // o caminho vira o nome do EHLO
            "--mail-from", smtp.sender,
            "--mail-rcpt", smtp.kindle,
            "--upload-file", messageFile.path,
            "--config", "-",            // usuário e senha via stdin
            "--progress-bar",
            "--show-error",
            "--connect-timeout", "30",
            "--max-time", "1800",
        ]
        // STARTTLS obrigatório fora do 465 (exceto relay local, útil para testes).
        if scheme == "smtp" && !isLocalRelay { args.append("--ssl-reqd") }

        Log.mail.info("Enviando para \(smtp.kindle, privacy: .public) via \(smtp.host, privacy: .public):\(port)")
        let r = try await ProcessRunner.run(Self.curl, args, stdin: Data(curlConfig.utf8)) { line in
            if let p = Self.parseProgress(line) { progress?(p) }
        }
        guard r.exitCode == 0 else {
            let detail = r.tail.split(whereSeparator: \.isNewline)
                .filter { !$0.contains("#") }.joined(separator: "\n")
            Log.mail.error("curl \(r.exitCode): \(detail, privacy: .public)")
            throw MailError.curl(code: r.exitCode, detail: detail)
        }
        Log.mail.info("E-mail enviado")
    }

    /// Formato de arquivo de config do curl, com aspas e barras escapadas.
    private var curlConfig: String {
        func q(_ s: String) -> String {
            "\"" + s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
        }
        return "user = \(q("\(smtp.sender):\(password)"))\n"
    }

    /// "######     45.3%" → 0.453
    static func parseProgress(_ line: String) -> Double? {
        guard line.hasSuffix("%") else { return nil }
        let number = line.dropLast().split(separator: " ").last.map(String.init) ?? ""
        return Double(number.replacingOccurrences(of: ",", with: ".")).map { $0 / 100 }
    }
}
