import AppKit

/// App oficial "Send to Kindle" da Amazon para Mac. O login é com a conta Amazon,
/// dentro do app da Amazon: nenhuma credencial passa pelo Lumink.
enum SendToKindleApp {
    static let downloadURL = URL(string: "https://www.amazon.com/sendtokindle")!
    /// Limite de arquivo do app para Mac (bem acima do limite de anexo do e-mail).
    static let limitBytes: Int64 = 200_000_000

    private static let bundleIDs = ["com.amazon.SendToKindle", "com.amazon.sendtokindle"]
    private static let appName = "Send to Kindle.app"

    /// Caminho do app, se estiver instalado.
    static func locate() -> URL? {
        for id in bundleIDs {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) { return url }
        }
        let fm = FileManager.default
        let dirs = [URL(fileURLWithPath: "/Applications"),
                    fm.homeDirectoryForCurrentUser.appendingPathComponent("Applications")]
        return dirs.map { $0.appendingPathComponent(appName) }
            .first { fm.fileExists(atPath: $0.path) }
    }

    /// Abre o EPUB no app; o usuário escolhe o dispositivo e confirma o envio lá.
    static func open(_ file: URL, with app: URL) async throws {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        _ = try await NSWorkspace.shared.open([file], withApplicationAt: app, configuration: configuration)
    }
}
