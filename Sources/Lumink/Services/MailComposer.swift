import Foundation

/// Monta uma mensagem MIME (RFC 5322 / 2045) com anexo opcional.
enum MailComposer {
    struct Attachment {
        var filename: String
        var mimeType: String
        var data: Data
    }

    static func build(from: String, to: String, subject: String, body: String,
                      attachment: Attachment? = nil, date: Date = Date()) -> Data {
        let boundary = "Lumink-\(UUID().uuidString)"
        var headers = [
            "From: \(from)",
            "To: \(to)",
            "Subject: \(encodeHeader(subject))",
            "Date: \(rfc5322Date(date))",
            "Message-ID: <\(UUID().uuidString)@lumink.local>",
            "MIME-Version: 1.0",
            "X-Mailer: Lumink",
        ]
        var parts: [String] = []
        let textPart = [
            "Content-Type: text/plain; charset=utf-8",
            "Content-Transfer-Encoding: base64",
            "",
            Data(body.utf8).base64EncodedString(options: [.lineLength76Characters, .endLineWithCarriageReturn, .endLineWithLineFeed]),
        ].joined(separator: "\r\n")

        if let attachment {
            headers.append("Content-Type: multipart/mixed; boundary=\"\(boundary)\"")
            parts.append(textPart)
            let name = attachment.filename.precomposedStringWithCanonicalMapping
            let ascii = asciiFilename(name)
            let encoded = name.addingPercentEncoding(withAllowedCharacters: .rfc2231) ?? ascii
            parts.append([
                "Content-Type: \(attachment.mimeType); name=\"\(ascii)\"",
                "Content-Disposition: attachment; filename=\"\(ascii)\"; filename*=UTF-8''\(encoded)",
                "Content-Transfer-Encoding: base64",
                "",
                attachment.data.base64EncodedString(options: [.lineLength76Characters, .endLineWithCarriageReturn, .endLineWithLineFeed]),
            ].joined(separator: "\r\n"))
            let body = parts.map { "--\(boundary)\r\n\($0)\r\n" }.joined() + "--\(boundary)--\r\n"
            return Data((headers.joined(separator: "\r\n") + "\r\n\r\n" + body).utf8)
        }

        headers.append("Content-Type: text/plain; charset=utf-8")
        headers.append("Content-Transfer-Encoding: base64")
        let b64 = Data(body.utf8).base64EncodedString(options: [.lineLength76Characters, .endLineWithCarriageReturn, .endLineWithLineFeed])
        return Data((headers.joined(separator: "\r\n") + "\r\n\r\n" + b64 + "\r\n").utf8)
    }

    /// RFC 2047 para cabeçalhos com acentos.
    static func encodeHeader(_ s: String) -> String {
        if s.allSatisfy({ $0.isASCII && !$0.isNewline }) { return s }
        return "=?UTF-8?B?\(Data(s.precomposedStringWithCanonicalMapping.utf8).base64EncodedString())?="
    }

    static func asciiFilename(_ name: String) -> String {
        let folded = name.folding(options: [.diacriticInsensitive, .widthInsensitive], locale: Locale(identifier: "en_US_POSIX"))
        let allowed = folded.unicodeScalars.map { s -> Character in
            (s.isASCII && s.value >= 0x20 && s != "\"" && s != "\\") ? Character(s) : "_"
        }
        return String(allowed)
    }

    static func rfc5322Date(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        return f.string(from: date)
    }
}

private extension CharacterSet {
    /// attr-char da RFC 2231/5987.
    static let rfc2231: CharacterSet = {
        var set = CharacterSet.alphanumerics.intersection(CharacterSet(charactersIn: Unicode.Scalar(0)...Unicode.Scalar(127)))
        set.insert(charactersIn: "!#$&+-.^_`|~")
        return set
    }()
}
