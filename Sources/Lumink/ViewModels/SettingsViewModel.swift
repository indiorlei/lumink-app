import Foundation
import Observation

@MainActor
@Observable
final class SettingsViewModel {
    var password: String = ""
    var passwordSaved = false
    var testState: TestState = .idle

    enum TestState: Equatable {
        case idle, sending, ok, failed(String)
    }

    func loadPassword(for account: String) {
        password = KeychainStore.password(for: account) ?? ""
        passwordSaved = !password.isEmpty
    }

    func savePassword(for account: String) {
        do {
            // Senhas de app do Google aparecem com espaços ("abcd efgh ..."); sem eles também funcionam.
            let cleaned = password.replacingOccurrences(of: " ", with: "")
            try KeychainStore.setPassword(cleaned, for: account)
            password = cleaned
            passwordSaved = !cleaned.isEmpty
        } catch {
            testState = .failed(error.localizedDescription)
        }
    }

    /// E-mail sem anexo para o próprio remetente: valida servidor, porta e senha
    /// sem gastar um documento no Kindle.
    /// Para testar o Kindle de verdade, processe um PDF pequeno.
    func sendTestEmail() {
        if !password.isEmpty { savePassword(for: SMTPConfig.current().sender) }
        testState = .sending
        Task {
            do {
                var smtp = SMTPConfig.current()
                smtp.kindle = smtp.sender
                let sender = try MailSender.configured(smtp)
                let message = MailComposer.build(
                    from: smtp.sender, to: smtp.sender, subject: "Lumink: e-mail de teste",
                    body: "Se você recebeu esta mensagem, o envio SMTP do Lumink está funcionando.\n\nLembre de adicionar \(smtp.sender) à lista de e-mails aprovados do Send to Kindle na Amazon."
                )
                let ws = try TempWorkspace()
                defer { ws.cleanup() }
                let file = ws.file("teste.eml")
                try message.write(to: file)
                try await MailSender(smtp: smtp, password: sender.password).send(messageFile: file)
                testState = .ok
            } catch {
                testState = .failed(error.localizedDescription)
            }
        }
    }
}
