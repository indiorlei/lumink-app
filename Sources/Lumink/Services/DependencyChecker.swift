import Foundation

struct DependencyStatus: Equatable, Sendable {
    var calibrePath: String?
    var ocrmypdfPath: String?

    var calibreOK: Bool { calibrePath != nil }
    var ocrmypdfOK: Bool { ocrmypdfPath != nil }
}

enum DependencyChecker {
    static let calibreDownloadURL = URL(string: "https://calibre-ebook.com/download_osx")!

    static func check(config: PipelineConfig = .current()) -> DependencyStatus {
        DependencyStatus(
            calibrePath: findCalibre(configured: config.calibrePath),
            ocrmypdfPath: findOCRmyPDF(configured: config.ocrmypdfPath)
        )
    }

    static func findCalibre(configured: String) -> String? {
        let candidates = [
            configured,
            SettingsDefault.calibrePath,
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Applications/calibre.app/Contents/MacOS/ebook-convert").path,
        ]
        return firstExecutable(candidates)
    }

    static func findOCRmyPDF(configured: String) -> String? {
        firstExecutable([configured, "/opt/homebrew/bin/ocrmypdf", "/usr/local/bin/ocrmypdf"])
    }

    private static func firstExecutable(_ paths: [String]) -> String? {
        paths.first { !$0.isEmpty && FileManager.default.isExecutableFile(atPath: $0) }
    }
}
