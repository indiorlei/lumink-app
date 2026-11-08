import os

/// Loggers por categoria. Veja no Console.app filtrando por "local.lumink",
/// ou: `log stream --predicate 'subsystem == "local.lumink"' --level debug`
enum Log {
    private static let subsystem = "local.lumink"
    static let app = Logger(subsystem: subsystem, category: "app")
    static let queue = Logger(subsystem: subsystem, category: "queue")
    static let process = Logger(subsystem: subsystem, category: "process")
    static let analyze = Logger(subsystem: subsystem, category: "analyze")
    static let ocr = Logger(subsystem: subsystem, category: "ocr")
    static let convert = Logger(subsystem: subsystem, category: "convert")
    static let compress = Logger(subsystem: subsystem, category: "compress")
    static let mail = Logger(subsystem: subsystem, category: "mail")
}
