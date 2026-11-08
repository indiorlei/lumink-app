import Foundation

/// Compacta/descompacta EPUBs com o zip/unzip do macOS.
enum EPUBArchive {
    static let mimetype = "application/epub+zip"

    static func unzip(_ epub: URL, to directory: URL) async throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try await ProcessRunner.runChecked("/usr/bin/unzip", ["-q", "-o", epub.path, "-d", directory.path], tool: "unzip")
    }

    /// Regra do EPUB (OCF): `mimetype` é a primeira entrada, sem compressão e sem
    /// campos extras (-X). O resto vai com compressão máxima.
    static func zip(directory: URL, to epub: URL) async throws {
        let fm = FileManager.default
        let mimeURL = directory.appendingPathComponent("mimetype")
        try mimetype.write(to: mimeURL, atomically: true, encoding: .ascii)
        try? fm.removeItem(at: epub)
        try await ProcessRunner.runChecked("/usr/bin/zip", ["-X", "-0", "-q", epub.path, "mimetype"],
                                           tool: "zip", currentDirectory: directory)
        try await ProcessRunner.runChecked("/usr/bin/zip", ["-X", "-9", "-r", "-q", epub.path, ".",
                                                            "-x", "mimetype", "-x", "*.DS_Store", "-x", "__MACOSX/*"],
                                           tool: "zip", currentDirectory: directory)
    }
}
