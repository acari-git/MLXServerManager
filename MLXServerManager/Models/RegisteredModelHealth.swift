import Foundation

nonisolated enum RegisteredModelHealthStatus: String, Equatable, Sendable {
    case ready
    case incomplete
    case missing
    case externalIdentifier
    case duplicatePath
    case uninspectable

    func localizedTitle(language: AppLanguage) -> String {
        let strings = AppLocalization(language: language)
        switch self {
        case .ready:
            return strings.text(english: "Ready", japanese: "利用可能")
        case .incomplete:
            return strings.text(english: "Incomplete", japanese: "不完全")
        case .missing:
            return strings.text(english: "Missing", japanese: "見つかりません")
        case .externalIdentifier:
            return strings.text(english: "External model ID", japanese: "外部モデルID")
        case .duplicatePath:
            return strings.text(english: "Shared local path", japanese: "ローカルパス重複")
        case .uninspectable:
            return strings.text(english: "Could not inspect", japanese: "確認できません")
        }
    }
}

nonisolated struct RegisteredModelHealthReport: Identifiable, Equatable, Sendable {
    let profileID: ModelConfig.ID
    let displayName: String
    let modelID: String
    let status: RegisteredModelHealthStatus
    let localPath: String?
    let issue: LocalModelIntegrityIssue?
    let message: String?
    let sizeGigabytes: Double?
    let modificationDate: Date?
    let duplicateProfileIDs: [ModelConfig.ID]
    let checkedAt: Date

    var id: ModelConfig.ID { profileID }

    func localizedDetail(language: AppLanguage) -> String {
        let strings = AppLocalization(language: language)
        switch status {
        case .ready:
            let sizeText = sizeGigabytes.map { String(format: "%.1f GB", $0) }
                ?? strings.text(english: "size unavailable", japanese: "サイズ不明")
            return strings.text(
                english: "Required local model files were detected. Estimated folder size: \(sizeText).",
                japanese: "必要なローカルモデルファイルを確認しました。推定フォルダサイズ: \(sizeText)。"
            )
        case .incomplete:
            return issue?.message(language: language)
                ?? strings.text(english: "Required model files are incomplete.", japanese: "必要なモデルファイルが不完全です。")
        case .missing:
            return strings.text(
                english: "The registered local model directory does not exist.",
                japanese: "登録済みのローカルモデルフォルダが存在しません。"
            )
        case .externalIdentifier:
            return strings.text(
                english: "This profile uses a model identifier rather than a registered local directory.",
                japanese: "このプロファイルは登録済みローカルフォルダではなくモデルIDを使用します。"
            )
        case .duplicatePath:
            return strings.text(
                english: "The same local path is used by \(duplicateProfileIDs.count + 1) profiles. The files are not duplicated or modified.",
                japanese: "同じローカルパスを\(duplicateProfileIDs.count + 1)件のプロファイルが使用しています。ファイルの複製や変更は行いません。"
            )
        case .uninspectable:
            return message ?? strings.text(
                english: "The local model directory could not be inspected.",
                japanese: "ローカルモデルフォルダを確認できませんでした。"
            )
        }
    }
}

nonisolated struct RegisteredModelHealthViewState: Equatable, Sendable {
    var reports: [RegisteredModelHealthReport]
    var isChecking: Bool
    var didCheck: Bool

    static let initial = RegisteredModelHealthViewState(
        reports: [],
        isChecking: false,
        didCheck: false
    )

    mutating func begin() {
        isChecking = true
    }

    mutating func complete(_ reports: [RegisteredModelHealthReport]) {
        self.reports = reports
        isChecking = false
        didCheck = true
    }

    mutating func cancel() {
        isChecking = false
    }

    func report(for profileID: ModelConfig.ID) -> RegisteredModelHealthReport? {
        reports.first { $0.profileID == profileID }
    }
}
