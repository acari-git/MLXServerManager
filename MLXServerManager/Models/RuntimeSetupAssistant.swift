import Foundation

nonisolated struct RuntimeSetupCandidate: Identifiable, Equatable, Sendable {
    let backend: InferenceBackend
    let executablePath: String
    let version: String?
    let source: RuntimeSetupCandidateSource

    var id: String { "\(backend.rawValue)|\(executablePath)" }

    func localizedSource(language: AppLanguage) -> String {
        let strings = AppLocalization(language: language)
        switch source {
        case .configured:
            return strings.text(english: "Configured path", japanese: "設定済みパス")
        case .environmentPath:
            return strings.text(english: "PATH environment", japanese: "PATH環境変数")
        case .commonLocation:
            return strings.text(english: "Common location", japanese: "一般的な場所")
        case .userEnvironment:
            return strings.text(english: "User environment", japanese: "ユーザー環境")
        }
    }
}

nonisolated enum RuntimeSetupCandidateSource: String, Equatable, Sendable {
    case configured
    case environmentPath
    case commonLocation
    case userEnvironment
}

nonisolated struct RuntimeSetupAssistantViewState: Equatable, Sendable {
    var candidates: [RuntimeSetupCandidate]
    var isSearching: Bool
    var didSearch: Bool
    var message: String?

    static let initial = RuntimeSetupAssistantViewState(
        candidates: [],
        isSearching: false,
        didSearch: false,
        message: nil
    )

    mutating func begin() {
        isSearching = true
        message = nil
    }

    mutating func complete(_ candidates: [RuntimeSetupCandidate]) {
        self.candidates = candidates
        isSearching = false
        didSearch = true
        message = nil
    }

    mutating func fail(_ message: String) {
        candidates = []
        isSearching = false
        didSearch = true
        self.message = message
    }

    mutating func cancel() {
        isSearching = false
    }
}
