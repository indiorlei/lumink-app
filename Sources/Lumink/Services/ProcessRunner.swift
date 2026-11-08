import Foundation

struct ProcessResult: Sendable {
    let exitCode: Int32
    /// Últimas linhas de stdout+stderr (para mensagens de erro).
    let tail: String
}

enum ProcessError: LocalizedError {
    case notFound(String)
    case failed(tool: String, code: Int32, tail: String)

    var errorDescription: String? {
        switch self {
        case .notFound(let path):
            "Executável não encontrado: \(path)"
        case .failed(let tool, let code, let tail):
            "\(tool) falhou (código \(code)).\n\(tail.suffix(600))"
        }
    }
}

/// Executa um processo em segundo plano, entregando o stdout/stderr linha a linha.
/// Cancelar a Task encerra o processo.
enum ProcessRunner {
    /// PATH para processos filhos. Apps abertos pelo Finder não herdam o PATH do
    /// shell, e o ocrmypdf precisa achar tesseract/ghostscript do Homebrew.
    static var childEnvironment: [String: String] {
        var env = ProcessInfo.processInfo.environment
        let extra = ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin", "/usr/sbin", "/sbin"]
        let current = env["PATH"].map { $0.split(separator: ":").map(String.init) } ?? []
        env["PATH"] = (extra + current.filter { !extra.contains($0) }).joined(separator: ":")
        env["LANG"] = env["LANG"] ?? "en_US.UTF-8"
        env["LC_ALL"] = "en_US.UTF-8"
        return env
    }

    @discardableResult
    static func run(
        _ executable: String,
        _ arguments: [String],
        stdin: Data? = nil,
        currentDirectory: URL? = nil,
        onLine: (@Sendable (String) -> Void)? = nil
    ) async throws -> ProcessResult {
        guard FileManager.default.isExecutableFile(atPath: executable) else {
            throw ProcessError.notFound(executable)
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.environment = childEnvironment
        if let currentDirectory { process.currentDirectoryURL = currentDirectory }

        let output = Pipe()
        process.standardOutput = output
        process.standardError = output
        let input = Pipe()
        process.standardInput = stdin == nil ? FileHandle.nullDevice : input

        let collector = LineCollector(onLine: onLine)
        output.fileHandleForReading.readabilityHandler = { handle in
            collector.append(handle.availableData)
        }

        Log.process.debug("▶︎ \(executable, privacy: .public) \(arguments.joined(separator: " "), privacy: .public)")

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<ProcessResult, Error>) in
                process.terminationHandler = { p in
                    output.fileHandleForReading.readabilityHandler = nil
                    collector.append(output.fileHandleForReading.readDataToEndOfFile())
                    collector.flush()
                    let result = ProcessResult(exitCode: p.terminationStatus, tail: collector.tail)
                    Log.process.debug("◀︎ \(executable, privacy: .public) saiu com \(p.terminationStatus)")
                    if collector.cancelled {
                        cont.resume(throwing: CancellationError())
                    } else {
                        cont.resume(returning: result)
                    }
                }
                do {
                    try process.run()
                    if let stdin {
                        input.fileHandleForWriting.write(stdin)
                        try? input.fileHandleForWriting.close()
                    }
                } catch {
                    cont.resume(throwing: error)
                }
            }
        } onCancel: {
            collector.cancelled = true
            if process.isRunning { process.terminate() }
        }
    }

    /// Roda e lança erro se o código de saída não estiver em `okCodes`.
    @discardableResult
    static func runChecked(
        _ executable: String,
        _ arguments: [String],
        tool: String,
        okCodes: Set<Int32> = [0],
        stdin: Data? = nil,
        currentDirectory: URL? = nil,
        onLine: (@Sendable (String) -> Void)? = nil
    ) async throws -> ProcessResult {
        let r = try await run(executable, arguments, stdin: stdin, currentDirectory: currentDirectory, onLine: onLine)
        guard okCodes.contains(r.exitCode) else {
            Log.process.error("\(tool, privacy: .public) falhou (\(r.exitCode)): \(r.tail, privacy: .public)")
            throw ProcessError.failed(tool: tool, code: r.exitCode, tail: r.tail)
        }
        return r
    }
}

/// Acumula bytes, quebra em linhas (\n ou \r, pois barras de progresso usam \r)
/// e guarda as últimas linhas.
private final class LineCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var buffer = Data()
    private var lines: [String] = []
    private let onLine: (@Sendable (String) -> Void)?
    private var _cancelled = false
    var cancelled: Bool {
        get { lock.lock(); defer { lock.unlock() }; return _cancelled }
        set { lock.lock(); _cancelled = newValue; lock.unlock() }
    }

    init(onLine: (@Sendable (String) -> Void)?) { self.onLine = onLine }

    func append(_ data: Data) {
        guard !data.isEmpty else { return }
        lock.lock()
        buffer.append(data)
        var emitted: [String] = []
        while let idx = buffer.firstIndex(where: { $0 == 0x0A || $0 == 0x0D }) {
            let lineData = buffer[buffer.startIndex..<idx]
            buffer.removeSubrange(buffer.startIndex...idx)
            if let line = String(data: lineData, encoding: .utf8), !line.isEmpty {
                emitted.append(line)
            }
        }
        record(emitted)
        lock.unlock()
        emitted.forEach { onLine?($0) }
    }

    func flush() {
        lock.lock()
        let rest = String(data: buffer, encoding: .utf8) ?? ""
        buffer.removeAll()
        if !rest.isEmpty { record([rest]) }
        lock.unlock()
        if !rest.isEmpty { onLine?(rest) }
    }

    var tail: String {
        lock.lock(); defer { lock.unlock() }
        return lines.suffix(25).joined(separator: "\n")
    }

    private func record(_ new: [String]) {
        lines.append(contentsOf: new)
        if lines.count > 200 { lines.removeFirst(lines.count - 200) }
    }
}
