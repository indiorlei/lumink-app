import Foundation
import Security

/// Guarda a senha de app do SMTP no Keychain do usuário (nunca em UserDefaults).
enum KeychainStore {
    private static let service = "local.lumink.smtp"

    enum KeychainError: LocalizedError {
        case status(OSStatus)
        var errorDescription: String? {
            if case .status(let s) = self {
                let msg = SecCopyErrorMessageString(s, nil) as String? ?? "erro \(s)"
                return "Keychain: \(msg)"
            }
            return nil
        }
    }

    static func password(for account: String) -> String? {
        guard !account.isEmpty else { return nil }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            if status != errSecItemNotFound { Log.app.error("Keychain leitura: \(status)") }
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    static func setPassword(_ password: String, for account: String) throws {
        guard !account.isEmpty else { return }
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        if password.isEmpty {
            SecItemDelete(base as CFDictionary)
            return
        }
        let data = Data(password.utf8)
        let update = SecItemUpdate(base as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if update == errSecItemNotFound {
            var add = base
            add[kSecValueData as String] = data
            add[kSecAttrLabel as String] = "Lumink – senha SMTP"
            let status = SecItemAdd(add as CFDictionary, nil)
            guard status == errSecSuccess else { throw KeychainError.status(status) }
        } else if update != errSecSuccess {
            throw KeychainError.status(update)
        }
    }
}
