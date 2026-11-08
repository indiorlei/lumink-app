import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            MailSettingsView()
                .tabItem { Label("Envio", systemImage: "paperplane") }
            ConversionSettingsView()
                .tabItem { Label("Conversão", systemImage: "doc.badge.gearshape") }
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
                Toggle("Só gerar o EPUB, sem enviar", isOn: $onlyGenerate)
                if useApp && useEmail {
                    Text("Com as duas opções ligadas, o Lumink usa o app Send to Kindle quando ele estiver instalado e o e-mail nos outros casos.")
                        .font(.caption).foregroundStyle(.secondary)
                } else if !useApp && !useEmail && !onlyGenerate {
                    Text("Ligue pelo menos uma forma de envio abaixo, ou os EPUBs só serão salvos.")
                        .font(.caption).foregroundStyle(.orange)
                }
            }
            Section {
                Toggle(isOn: $useApp) {
                    Text("App Send to Kindle (recomendado)")
                    Text("O Lumink abre o EPUB no app oficial da Amazon, e você confirma o envio por lá. O login é com a sua conta Amazon, dentro do app da Amazon: nenhuma senha passa pelo Lumink.")
                }
                if useApp {
                    if let appURL {
                        Label("Instalado em \(appURL.deletingLastPathComponent().path)", systemImage: "checkmark.circle.fill")
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        HStack {
                            Label("Não instalado", systemImage: "exclamationmark.triangle.fill")
                                .font(.caption).foregroundStyle(.orange)
                            Spacer()
                            Link("Baixar na Amazon", destination: SendToKindleApp.downloadURL)
                            Button("Verificar novamente") { appURL = SendToKindleApp.locate() }
                                .controlSize(.small)
                        }
                    }
                }
            }
            Section {
                Toggle(isOn: $useEmail) {
                    Text("E-mail (Gmail ou outro SMTP)")
                    Text("Envia sozinho, sem abrir outro app. Precisa do e-mail do Kindle e de uma senha de app do Gmail, que fica no Keychain deste Mac.")
                }
                if useEmail {
                    TextField("E-mail do Kindle", text: $kindleEmail, prompt: Text("nome_123@kindle.com"))
                    if !kindleEmail.isEmpty && !kindleEmail.lowercased().hasSuffix("@kindle.com") {
                        Text("O endereço do Send to Kindle costuma terminar em @kindle.com.")
                            .font(.caption).foregroundStyle(.orange)
                    }
                    TextField("E-mail remetente", text: $senderEmail, prompt: Text("voce@gmail.com"))
                        .onChange(of: senderEmail) { _, new in model.loadPassword(for: new) }
                    TextField("Servidor", text: $smtpHost, prompt: Text("smtp.gmail.com"))
                    TextField("Porta", value: $smtpPort, format: .number.grouping(.never), prompt: Text("465"))
                    HStack {
                        SecureField("Senha de app", text: $model.password)
                        Button("Salvar no Keychain") { model.savePassword(for: senderEmail) }
                            .disabled(senderEmail.isEmpty)
                    }
                    if model.passwordSaved {
                        Label("Senha guardada no Keychain", systemImage: "lock.fill")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Text("Use uma senha de app, não a senha normal da conta. Porta 465 usa SSL direto (smtps); outras portas (ex.: 587) usam STARTTLS. Lembre de adicionar o remetente à lista de e-mails aprovados na Amazon.")
                        .font(.caption).foregroundStyle(.secondary)
                    if SMTPConfig(host: smtpHost, port: smtpPort, sender: "", kindle: "").providerAttachmentLimitBytes != nil {
                        Text("O Gmail recusa mensagens acima de 25 MB; o app limita o anexo a ~18 MB automaticamente.")
                            .font(.caption).foregroundStyle(.orange)
                    }
                    Stepper("Limite do anexo: \(maxAttachmentMB) MB", value: $maxAttachmentMB, in: 5...50)
                    Text("O teste envia um e-mail sem anexo para o próprio remetente: valida servidor, porta e senha sem gastar um documento no Kindle.")
                        .font(.caption).foregroundStyle(.secondary)
                    HStack {
                        Button("Enviar e-mail de teste") { model.sendTestEmail() }
                            .disabled(model.testState == .sending || senderEmail.isEmpty)
                        switch model.testState {
                        case .idle: EmptyView()
                        case .sending: ProgressView().controlSize(.small)
                        case .ok: Text("✅ Enviado").font(.callout)
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
            Section("Ferramentas") {
                LabeledContent("ebook-convert") {
                    PathField(path: $calibrePath, found: DependencyChecker.findCalibre(configured: calibrePath))
                }
                LabeledContent("ocrmypdf") {
                    PathField(path: $ocrmypdfPath, placeholder: "automático (Homebrew)",
                              found: DependencyChecker.findOCRmyPDF(configured: ocrmypdfPath))
                }
                TextField("Idiomas do OCR", text: $ocrLanguages, prompt: Text("por+eng"))
            }
            Section("Padrões") {
                Picker("Qualidade", selection: $compression) {
                    ForEach(CompressionLevel.allCases) { level in
                        Text("\(level.label) (\(level.detail))").tag(level.rawValue)
                    }
                }
                Toggle("Revisar título e autor antes de processar", isOn: $review)
                Toggle("Modo imagem (HQ/mangá) por padrão", isOn: $imageModeDefault)
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
            Text(found.map { "✓ \($0)" } ?? "não encontrado")
                .font(.caption2)
                .foregroundStyle(found == nil ? .red : .secondary)
        }
    }
}
