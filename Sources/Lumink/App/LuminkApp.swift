import SwiftUI
import AppKit

@main
struct LuminkApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        // Necessário quando o binário roda fora de um .app (ex.: `swift run`).
        NSApplication.shared.setActivationPolicy(.regular)
        TempWorkspace.cleanStaleDirectories()
        DebugCommands.handleIfNeeded()
        Log.app.info("Lumink iniciado")
    }

    var body: some Scene {
        Window("Lumink", id: "main") {
            MainView()
                .environment(appDelegate.queue)
                .frame(minWidth: 640, minHeight: 480)
                .modifier(ShowReleaseNotesOnUpdate())
        }
        .windowResizability(.contentMinSize)
        .commands { ReleaseNotesCommands() }

        Window("Novidades do Lumink", id: ReleaseNotesWindow.id) {
            ReleaseNotesView()
                .frame(width: 520, height: 600)
        }
        .windowResizability(.contentSize)

        Settings {
            SettingsView()
        }
    }
}

/// Recebe PDFs arrastados para o ícone do Dock ou abertos com "Abrir com".
final class AppDelegate: NSObject, NSApplicationDelegate {
    @MainActor let queue = QueueViewModel()

    @MainActor
    func application(_ application: NSApplication, open urls: [URL]) {
        Log.app.info("Abrindo \(urls.count) arquivo(s) pelo sistema")
        queue.add(urls: urls)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
