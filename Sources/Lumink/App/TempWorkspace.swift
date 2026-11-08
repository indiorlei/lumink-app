import Foundation

/// Pasta temporária por job, removida ao final.
struct TempWorkspace {
    static let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("Lumink", isDirectory: true)

    let url: URL

    init() throws {
        url = Self.root.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    func file(_ name: String) -> URL { url.appendingPathComponent(name) }

    func cleanup() {
        try? FileManager.default.removeItem(at: url)
    }

    /// Remove sobras de execuções anteriores (ex.: app encerrado no meio).
    static func cleanStaleDirectories() {
        try? FileManager.default.removeItem(at: root)
    }
}

enum OutputLocation {
    static var directory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents/Lumink", isDirectory: true)
    }

    /// Caminho único em ~/Documents/Lumink para o título informado.
    static func uniqueURL(forTitle title: String, ext: String = "epub") throws -> URL {
        let dir = directory
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let base = sanitize(title)
        var candidate = dir.appendingPathComponent("\(base).\(ext)")
        var n = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = dir.appendingPathComponent("\(base) (\(n)).\(ext)")
            n += 1
        }
        return candidate
    }

    static func sanitize(_ name: String) -> String {
        let bad = CharacterSet(charactersIn: "/\\:?%*|\"<>\n\r\t")
        let cleaned = name.precomposedStringWithCanonicalMapping
            .components(separatedBy: bad).joined(separator: " ")
            .split(separator: " ", omittingEmptySubsequences: true).joined(separator: " ")
        let result = cleaned.isEmpty ? "livro" : cleaned
        return String(result.prefix(120))
    }
}
