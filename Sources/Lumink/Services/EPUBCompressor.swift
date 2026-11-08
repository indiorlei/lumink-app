import Foundation

/// Descompacta o EPUB, recomprime as imagens, corrige referências e recompacta.
struct EPUBCompressor: Sendable {
    struct Stats: Sendable {
        var images = 0
        var rewritten = 0
        var converted = 0
        var savedBytes: Int64 = 0
    }

    static let imageExtensions: Set<String> = ["jpg", "jpeg", "png"]
    static let textExtensions: Set<String> = ["opf", "xhtml", "html", "htm", "css", "ncx", "xml", "svg"]

    func compress(_ epub: URL, to output: URL, level: CompressionLevel, workDir: URL,
                  progress: @escaping @Sendable (Double) -> Void) async throws -> Stats {
        let dir = workDir.appendingPathComponent("compress-\(level.rawValue)", isDirectory: true)
        try? FileManager.default.removeItem(at: dir)
        try await EPUBArchive.unzip(epub, to: dir)
        progress(0.05)

        let files = Self.allFiles(in: dir)
        let images = files.filter { Self.imageExtensions.contains($0.pathExtension.lowercased()) }
        var stats = Stats(images: images.count)
        var renames: [(old: String, new: String)] = []

        let recompressor = ImageRecompressor(level: level)
        let batchSize = max(2, ProcessInfo.processInfo.activeProcessorCount)
        var done = 0
        for batch in stride(from: 0, to: images.count, by: batchSize).map({ Array(images[$0..<min($0 + batchSize, images.count)]) }) {
            try Task.checkCancellation()
            let outcomes = Self.parallelMap(batch) { recompressor.process($0) }
            for (url, outcome) in zip(batch, outcomes) {
                switch outcome {
                case .unchanged: break
                case .rewritten(let saved):
                    stats.rewritten += 1; stats.savedBytes += saved
                case .converted(let newURL, let saved):
                    stats.converted += 1; stats.savedBytes += saved
                    renames.append((url.lastPathComponent, newURL.lastPathComponent))
                }
            }
            done += batch.count
            progress(0.05 + 0.85 * Double(done) / Double(max(1, images.count)))
        }

        if !renames.isEmpty {
            try Self.updateReferences(in: files.filter { Self.textExtensions.contains($0.pathExtension.lowercased()) },
                                      renames: renames)
        }
        try await EPUBArchive.zip(directory: dir, to: output)
        try? FileManager.default.removeItem(at: dir)
        progress(1)
        Log.compress.info("Compressão \(level.rawValue, privacy: .public): \(stats.images) imagens, \(stats.rewritten) reescritas, \(stats.converted) PNG→JPEG, \(stats.savedBytes) bytes economizados")
        return stats
    }

    // MARK: - Referências

    /// Troca "foto.png" por "foto.jpg" em href/src/url() e corrige o media-type no OPF.
    static func updateReferences(in textFiles: [URL], renames: [(old: String, new: String)]) throws {
        let patterns = renames.map { r in
            (regex: try! NSRegularExpression(pattern: #"(?<=[/"'(=]|^)"# + NSRegularExpression.escapedPattern(for: r.old) + #"(?=["')#?\s]|$)"#,
                                             options: [.anchorsMatchLines]),
             new: r.new)
        }
        let newNames = Set(renames.map(\.new))
        for file in textFiles {
            guard var text = try? String(contentsOf: file, encoding: .utf8) else { continue }
            let original = text
            for p in patterns {
                text = p.regex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text),
                                                        withTemplate: NSRegularExpression.escapedTemplate(for: p.new))
            }
            if file.pathExtension.lowercased() == "opf" {
                text = fixMediaTypes(in: text, jpegNames: newNames)
            }
            if text != original { try text.write(to: file, atomically: true, encoding: .utf8) }
        }
    }

    static func fixMediaTypes(in opf: String, jpegNames: Set<String>) -> String {
        let itemRegex = try! NSRegularExpression(pattern: #"<item\b[^>]*>"#)
        var result = opf
        for match in itemRegex.matches(in: opf, range: NSRange(opf.startIndex..., in: opf)).reversed() {
            guard let range = Range(match.range, in: result) else { continue }
            let tag = String(result[range])
            guard jpegNames.contains(where: { tag.contains("\($0)\"") || tag.contains("\($0)'") }) else { continue }
            let fixed = tag.replacingOccurrences(of: "image/png", with: "image/jpeg")
            result.replaceSubrange(range, with: fixed)
        }
        return result
    }

    // MARK: - Utilidades

    static func allFiles(in dir: URL) -> [URL] {
        let e = FileManager.default.enumerator(at: dir, includingPropertiesForKeys: [.isRegularFileKey])
        return (e?.allObjects as? [URL] ?? []).filter {
            (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
        }
    }

    static func parallelMap<T: Sendable, R: Sendable>(_ items: [T], _ transform: @Sendable (T) -> R) -> [R] {
        let results = UnsafeMutableBufferPointer<R?>.allocate(capacity: items.count)
        results.initialize(repeating: nil)
        defer { results.deallocate() }
        DispatchQueue.concurrentPerform(iterations: items.count) { i in
            autoreleasepool { results[i] = transform(items[i]) }
        }
        return results.map { $0! }
    }
}
