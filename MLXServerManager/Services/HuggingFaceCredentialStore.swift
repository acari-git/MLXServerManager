import Foundation
import Security

protocol HuggingFaceCredentialStoring {
    func readValue() -> String?
    func saveValue(_ value: String)
    func deleteValue()
}

final class HuggingFaceCredentialStore: HuggingFaceCredentialStoring {
    private let service = "MLXServerManager.HuggingFaceAccess"
    private let account = "default"

    func readValue() -> String? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8),
              !value.isEmpty else {
            return nil
        }
        return value
    }

    func saveValue(_ value: String) {
        let data = Data(value.utf8)
        var attributes = baseQuery()
        attributes[kSecValueData as String] = data

        let status = SecItemAdd(attributes as CFDictionary, nil)
        if status == errSecDuplicateItem {
            SecItemUpdate(baseQuery() as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        }
    }

    func deleteValue() {
        SecItemDelete(baseQuery() as CFDictionary)
    }

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
    }
}
