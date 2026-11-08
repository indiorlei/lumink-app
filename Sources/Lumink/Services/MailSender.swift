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
                loc("E-mail não configurado: \(what). Abra Configurações (⌘,) → Envio.",
                    "Email isn't set up: \(what). Open Settings (⌘,) → Delivery.")
            case .curl(let code, let detail):
                "\(Self.explain(code)) (curl \(code))\n\(detail.suffix(400))"
            }
        }

        static func explain(_ code: Int32) -> String {
            switch code {
            case 6: loc("Servidor SMTP não encontrado. Confira o endereço.",
                        "SMTP server not found. Check the address.")
            case 7: loc("Não foi possível conectar ao servidor SMTP. Confira servidor, porta e a internet.",
                        "Couldn't connect to the SMTP server. Check the server, the port and your internet connection.")
            case 28: loc("Tempo esgotado ao falar com o servidor SMTP.",
                         "Timed out talking to the SMTP server.")
            case 35, 60: loc("Falha na conexão segura (TLS) com o servidor.",
                             "The secure connection (TLS) to the server failed.")
            case 55: loc("O servidor recusou a mensagem (talvez seja grande demais).",
                         "The server rejected the message (it may be too large).")
            case 67: loc("Login recusado. No Gmail, use uma senha de app (não a senha normal da conta).",
                         "Login rejected. With Gmail, use an app password (not your regular account password).")
            default: loc("Falha ao enviar o e-mail.", "Failed to send the email.")
            }
        }
    }

    /// Lê a senha do Keychain e valida a configuração.
    static func configured(_ smtp: SMTPConfig, passwordOverride: String? = nil) throws -> MailSender {
        if smtp.kindle.isEmpty { throw MailError.notConfigured(loc("falta o e-mail do Kindle", "the Kindle email is missing")) }
        if smtp.sender.isEmpty { throw MailError.notConfigured(loc("falta o e-mail remetente", "the sender email is missing")) }
        if smtp.host.isEmpty { throw MailError.notConfigured(loc("falta o servidor SMTP", "the SMTP server is missing")) }
        guard let password = passwordOverride ?? KeychainStore.password(for: smtp.sender), !password.isEmpty else {
            throw MailError.notConfigured(loc("falta a senha de app (salve no Keychain)", "the app password is missing (save it to the Keychain)"))
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
