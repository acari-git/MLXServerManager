import Foundation

protocol HuggingFaceCredentialStoring {
    func readValue() -> String?
    func saveValue(_ value: String)
    func deleteValue()
}

final class HuggingFaceCredentialStore: HuggingFaceCredentialStoring {
    private let key = "huggingFaceCredentialConfiguredValue"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func readValue() -> String? {
        let value = defaults.string(forKey: key)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return value?.isEmpty == false ? value : nil
    }

    func saveValue(_ value: String) {
        defaults.set(value, forKey: key)
    }

    func deleteValue() {
        defaults.removeObject(forKey: key)
    }
}
