import Foundation

nonisolated enum RuntimeCompatibilityFeature: String, CaseIterable, Identifiable, Sendable {
    case modelSelection
    case hostAndPort
    case cors
    case chatTemplate
    case trustRemoteCode
    case speculativeDecoding
    case reasoningControl
    case toolCallParser

    var id: String { rawValue }

    func localizedTitle(language: AppLanguage) -> String {
        let strings = AppLocalization(language: language)
        switch self {
        case .modelSelection:
            return strings.text(english: "Model selection", japanese: "モデル指定")
        case .hostAndPort:
            return strings.text(english: "Host and port", japanese: "ホストとポート")
        case .cors:
            return strings.text(english: "CORS origins", japanese: "CORSオリジン")
        case .chatTemplate:
            return strings.text(english: "Chat template", japanese: "チャットテンプレート")
        case .trustRemoteCode:
            return strings.text(english: "Trust remote code", japanese: "Remote Code許可")
        case .speculativeDecoding:
            return strings.text(english: "Speculative decoding", japanese: "投機的デコード")
        case .reasoningControl:
            return strings.text(english: "Reasoning control", japanese: "推論制御")
        case .toolCallParser:
            return strings.text(english: "Tool-call parser", japanese: "ツールコールパーサー")
        }
    }

    var recognizedFlags: Set<String> {
        switch self {
        case .modelSelection:
            ["--model"]
        case .hostAndPort:
            ["--host", "--port"]
        case .cors:
            ["--allowed-origins", "--cors-origins"]
        case .chatTemplate:
            ["--chat-template", "--chat-template-args"]
        case .trustRemoteCode:
            ["--trust-remote-code"]
        case .speculativeDecoding:
            ["--draft-model", "--num-draft-tokens"]
        case .reasoningControl:
            ["--no-thinking", "--reasoning-parser", "--no-reasoning-parser"]
        case .toolCallParser:
            ["--tool-call-parser"]
        }
    }
}

nonisolated enum RuntimeCompatibilitySupport: String, Equatable, Sendable {
    case supported
    case partial
    case unsupported
    case unknown

    func localizedTitle(language: AppLanguage) -> String {
        let strings = AppLocalization(language: language)
        switch self {
        case .supported:
            return strings.text(english: "Supported", japanese: "対応")
        case .partial:
            return strings.text(english: "Partial", japanese: "一部対応")
        case .unsupported:
            return strings.text(english: "Not detected", japanese: "未検出")
        case .unknown:
            return strings.text(english: "Unknown", japanese: "不明")
        }
    }
}

nonisolated struct RuntimeCompatibilityFeatureResult: Identifiable, Equatable, Sendable {
    let feature: RuntimeCompatibilityFeature
    let support: RuntimeCompatibilitySupport
    let detectedFlags: [String]

    var id: RuntimeCompatibilityFeature { feature }
}

nonisolated struct RuntimeCompatibilityReport: Identifiable, Equatable, Sendable {
    let backend: InferenceBackend
    let executablePath: String
    let version: String?
    let supportedFlags: Set<String>?
    let features: [RuntimeCompatibilityFeatureResult]
    let checkedAt: Date

    var id: InferenceBackend { backend }
}

nonisolated struct RuntimeCompatibilityViewState: Equatable, Sendable {
    var reports: [RuntimeCompatibilityReport]
    var isChecking: Bool
    var didCheck: Bool

    static let initial = RuntimeCompatibilityViewState(reports: [], isChecking: false, didCheck: false)

    mutating func begin() {
        isChecking = true
    }

    mutating func complete(_ reports: [RuntimeCompatibilityReport]) {
        self.reports = reports
        isChecking = false
        didCheck = true
    }

    mutating func cancel() {
        isChecking = false
    }
}
