import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            MailSettingsView()
                .tabItem { Label(loc("Envio", "Delivery"), systemImage: "paperplane") }
            ConversionSettingsView()
                .tabItem { Label(loc("Conversão", "Conversion"), systemImage: "doc.badge.gearshape") }
        }
        .frame(width: 540)
        .padding()
    }
}

private struct MailSettingsView: View {
    @AppStorage(SettingsKey.kindleEmail) private var kindleEmail = ""
    @AppStorage(SettingsKey.senderEmail) private var senderEmail = ""
    @AppStorage(SettingsKey.smtpHost) private var smtpHost = SettingsDefault.smtpHost
    @AppStorage(SettingsKey.smtpPort) private var smtpPort = SettingsDefault.smtpPort
    @AppStorage(SettingsKey.onlyGenerate) private var onlyGenerate = false
    @AppStorage(SettingsKey.maxAttachmentMB) private var maxAttachmentMB = SettingsDefault.maxAttachmentMB
    @AppStorage(SettingsKey.useSendToKindleApp) private var useApp = true
    @AppStorage(SettingsKey.useEmail) private var useEmail = false
    @State private var model = SettingsViewModel()
    @State private var appURL = SendToKindleApp.locate()

    var body: some View {
        Form {
            Section {
                Toggle(loc("Só gerar o EPUB, sem enviar", "Only generate the EPUB, without sending it"), isOn: $onlyGenerate)
                if useApp && useEmail {
                    Text(loc("Com as duas opções ligadas, o Lumink usa o app Send to Kindle quando ele estiver instalado e o e-mail nos outros casos.", "With both options on, Lumink uses the Send to Kindle app when it's installed and email otherwise."))
                        .font(.caption).foregroundStyle(.secondary)
                } else if !useApp && !useEmail && !onlyGenerate {
                    Text(loc("Ligue pelo menos uma forma de envio abaixo, ou os EPUBs só serão salvos.", "Turn on at least one delivery method below, or the EPUBs will only be saved."))
                        .font(.caption).foregroundStyle(.orange)
                }
            }
            Section {
                Toggle(isOn: $useApp) {
                    Text(loc("App Send to Kindle (recomendado)", "Send to Kindle app (recommended)"))
                    Text(loc("O Lumink abre o EPUB no app oficial da Amazon, e você confirma o envio por lá. O login é com a sua conta Amazon, dentro do app da Amazon: nenhuma senha passa pelo Lumink.", "Lumink opens the EPUB in Amazon's official app, and you confirm the delivery there. You sign in with your Amazon account, inside Amazon's app: no password goes through Lumink."))
                }
                if useApp {
                    if let appURL {
                        Label(loc("Instalado em \(appURL.deletingLastPathComponent().path)",
                                   "Installed in \(appURL.deletingLastPathComponent().path)"), systemImage: "checkmark.circle.fill")
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        HStack {
                            Label(loc("Não instalado", "Not installed"), systemImage: "exclamationmark.triangle.fill")
                                .font(.caption).foregroundStyle(.orange)
                            Spacer()
                            Link(loc("Baixar na Amazon", "Download from Amazon"), destination: SendToKindleApp.downloadURL)
                            Button(loc("Verificar novamente", "Check again")) { appURL = SendToKindleApp.locate() }
                                .controlSize(.small)
                        }
                    }
                }
            }
            Section {
                Toggle(isOn: $useEmail) {
                    Text(loc("E-mail (Gmail ou outro SMTP)", "Email (Gmail or another SMTP server)"))
                    Text(loc("Envia sozinho, sem abrir outro app. Precisa do e-mail do Kindle e de uma senha de app do Gmail, que fica no Keychain deste Mac.", "Sends on its own, without opening another app. Needs your Kindle email and a Gmail app password, which stays in this Mac's Keychain."))
                }
                if useEmail {
                    TextField(loc("E-mail do Kindle", "Kindle email"), text: $kindleEmail, prompt: Text(loc("nome_123@kindle.com", "name_123@kindle.com")))
                    if !kindleEmail.isEmpty && !kindleEmail.lowercased().hasSuffix("@kindle.com") {
                        Text(loc("O endereço do Send to Kindle costuma terminar em @kindle.com.", "The Send to Kindle address usually ends in @kindle.com."))
                            .font(.caption).foregroundStyle(.orange)
                    }
                    TextField(loc("E-mail remetente", "Sender email"), text: $senderEmail, prompt: Text(loc("voce@gmail.com", "you@gmail.com")))
                        .onChange(of: senderEmail) { _, new in model.loadPassword(for: new) }
                    TextField(loc("Servidor", "Server"), text: $smtpHost, prompt: Text("smtp.gmail.com"))
                    TextField(loc("Porta", "Port"), value: $smtpPort, format: .number.grouping(.never), prompt: Text("465"))
                    HStack {
                        SecureField(loc("Senha de app", "App password"), text: $model.password)
                        Button(loc("Salvar no Keychain", "Save to Keychain")) { model.savePassword(for: senderEmail) }
                            .disabled(senderEmail.isEmpty)
                    }
                    if model.passwordSaved {
                        Label(loc("Senha guardada no Keychain", "Password stored in the Keychain"), systemImage: "lock.fill")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Text(loc("Use uma senha de app, não a senha normal da conta. Porta 465 usa SSL direto (smtps); outras portas (ex.: 587) usam STARTTLS. Lembre de adicionar o remetente à lista de e-mails aprovados na Amazon.", "Use an app password, not your regular account password. Port 465 uses direct SSL (smtps); other ports (e.g. 587) use STARTTLS. Remember to add the sender to the approved email list on Amazon."))
                        .font(.caption).foregroundStyle(.secondary)
                    if SMTPConfig(host: smtpHost, port: smtpPort, sender: "", kindle: "").providerAttachmentLimitBytes != nil {
                        Text(loc("O Gmail recusa mensagens acima de 25 MB; o app limita o anexo a ~18 MB automaticamente.", "Gmail rejects messages over 25 MB; the app limits the attachment to ~18 MB automatically."))
                            .font(.caption).foregroundStyle(.orange)
                    }
                    Stepper(loc("Limite do anexo: \(maxAttachmentMB) MB", "Attachment limit: \(maxAttachmentMB) MB"), value: $maxAttachmentMB, in: 5...50)
                    Text(loc("O teste envia um e-mail sem anexo para o próprio remetente: valida servidor, porta e senha sem gastar um documento no Kindle.", "The test sends an email with no attachment to the sender itself: it checks the server, port and password without using up a document on the Kindle."))
                        .font(.caption).foregroundStyle(.secondary)
                    HStack {
                        Button(loc("Enviar e-mail de teste", "Send test email")) { model.sendTestEmail() }
                            .disabled(model.testState == .sending || senderEmail.isEmpty)
                        switch model.testState {
                        case .idle: EmptyView()
                        case .sending: ProgressView().controlSize(.small)
                        case .ok: Text(loc("✅ Enviado", "✅ Sent")).font(.callout)
                        case .failed(let msg):
                            Text("❌ \(msg)").font(.caption).foregroundStyle(.red)
                                .textSelection(.enabled).lineLimit(6)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            appURL = SendToKindleApp.locate()
            model.loadPassword(for: senderEmail)
        }
    }
}

private struct ConversionSettingsView: View {
    @AppStorage(SettingsKey.calibrePath) private var calibrePath = SettingsDefault.calibrePath
    @AppStorage(SettingsKey.ocrmypdfPath) private var ocrmypdfPath = SettingsDefault.ocrmypdfPath
    @AppStorage(SettingsKey.ocrLanguages) private var ocrLanguages = SettingsDefault.ocrLanguages
    @AppStorage(SettingsKey.compressionLevel) private var compression = SettingsDefault.compressionLevel
    @AppStorage(SettingsKey.reviewBeforeProcessing) private var review = true
    @AppStorage(SettingsKey.imageModeDefault) private var imageModeDefault = false

    var body: some View {
        Form {
            Section(loc("Ferramentas", "Tools")) {
                LabeledContent("ebook-convert") {
                    PathField(path: $calibrePath, found: DependencyChecker.findCalibre(configured: calibrePath))
                }
                LabeledContent("ocrmypdf") {
                    PathField(path: $ocrmypdfPath, placeholder: loc("automático (Homebrew)", "automatic (Homebrew)"),
                              found: DependencyChecker.findOCRmyPDF(configured: ocrmypdfPath))
                }
                TextField(loc("Idiomas do OCR", "OCR languages"), text: $ocrLanguages, prompt: Text("por+eng"))
            }
            Section(loc("Padrões", "Defaults")) {
                Picker(loc("Qualidade", "Quality"), selection: $compression) {
                    ForEach(CompressionLevel.allCases) { level in
                        Text("\(level.label) (\(level.detail))").tag(level.rawValue)
                    }
                }
                Toggle(loc("Revisar título e autor antes de processar", "Review title and author before processing"), isOn: $review)
                Toggle(loc("Modo imagem (HQ/mangá) por padrão", "Image mode (comics/manga) by default"), isOn: $imageModeDefault)
            }
        }
        .formStyle(.grouped)
    }
}

private struct PathField: View {
    @Binding var path: String
    var placeholder: String = ""
    let found: String?

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            TextField("", text: $path, prompt: Text(placeholder))
                .font(.caption.monospaced())
            Text(found.map { "✓ \($0)" } ?? loc("não encontrado", "not found"))
                .font(.caption2)
                .foregroundStyle(found == nil ? .red : .secondary)
        }
    }
}
