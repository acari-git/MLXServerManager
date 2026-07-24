import Foundation

enum RecoverySeverity: String, Codable, Hashable {
    case ok = "OK"
    case warning = "Warning"
    case failed = "Failed"
    case review = "Needs Review"

    func localizedTitle(language: AppLanguage) -> String {
        guard language.resolved == .japanese else {
            return rawValue
        }
        switch self {
        case .ok:
            return "問題なし"
        case .warning:
            return "警告"
        case .failed:
            return "失敗"
        case .review:
            return "要確認"
        }
    }
}

enum RecoveryIssueCategory: String, Codable, CaseIterable, Hashable {
    case none
    case executableMissing
    case executableNotExecutable
    case modelPathMissing
    case portBusy
    case permissionDenied
    case readinessTimeout
    case processExitedEarly
    case huggingFaceCLIMissing
    case huggingFaceAccess
    case network
    case destination
    case profileRegistration
    case unknown

    var title: String {
        switch self {
        case .none: "No recovery needed"
        case .executableMissing: "Executable Missing"
        case .executableNotExecutable: "Executable Not Executable"
        case .modelPathMissing: "Model Path Missing"
        case .portBusy: "Port Busy"
        case .permissionDenied: "Permission Denied"
        case .readinessTimeout: "Readiness Timeout"
        case .processExitedEarly: "Process Exited Early"
        case .huggingFaceCLIMissing: "HF CLI Missing"
        case .huggingFaceAccess: "HF Access / Gated Model"
        case .network: "Network Error"
        case .destination: "Destination Error"
        case .profileRegistration: "Profile Add Failed"
        case .unknown: "Unknown Issue"
        }
    }

    func localizedTitle(language: AppLanguage) -> String {
        guard language.resolved == .japanese else {
            return title
        }
        switch self {
        case .none: return "復旧不要"
        case .executableMissing: return "実行ファイルがありません"
        case .executableNotExecutable: return "実行ファイルを実行できません"
        case .modelPathMissing: return "モデルパスがありません"
        case .portBusy: return "ポート使用中"
        case .permissionDenied: return "権限がありません"
        case .readinessTimeout: return "Ready確認タイムアウト"
        case .processExitedEarly: return "プロセスが早期終了しました"
        case .huggingFaceCLIMissing: return "HF CLIがありません"
        case .huggingFaceAccess: return "HFアクセス / ゲート付きモデル"
        case .network: return "ネットワークエラー"
        case .destination: return "保存先エラー"
        case .profileRegistration: return "プロファイル追加失敗"
        case .unknown: return "不明な問題"
        }
    }
}

struct RecoveryAction: Identifiable, Hashable {
    enum Kind: String, Hashable {
        case openSettings
        case openModels
        case openDownloads
        case openLogs
        case editProfile
        case checkPort
        case runDiagnostics
        case runReadyCheck
        case retryDownload
        case retryProfileRegistration
        case restoreDownloadForm
        case copyURL
        case copyTroubleshooting
        case copySafety
    }

    var id: String {
        [kind.rawValue, downloadQueueEntryID?.uuidString]
            .compactMap { $0 }
            .joined(separator: ":")
    }
    let kind: Kind
    let title: String
    let detail: String
    let isPrimary: Bool
    let downloadQueueEntryID: UUID?

    init(
        kind: Kind,
        title: String,
        detail: String,
        isPrimary: Bool,
        downloadQueueEntryID: UUID? = nil
    ) {
        self.kind = kind
        self.title = title
        self.detail = detail
        self.isPrimary = isPrimary
        self.downloadQueueEntryID = downloadQueueEntryID
    }

    func localizedTitle(language: AppLanguage) -> String {
        guard language.resolved == .japanese else {
            return title
        }
        switch kind {
        case .openSettings: return "設定を開く"
        case .openModels: return "モデル一覧を開く"
        case .openDownloads: return "ダウンロードを開く"
        case .openLogs: return "ログを開く"
        case .editProfile: return "プロファイルを編集"
        case .checkPort: return "ポートを確認"
        case .runDiagnostics: return "診断を実行"
        case .runReadyCheck: return "Ready確認を実行"
        case .retryDownload: return "ダウンロードを再試行"
        case .retryProfileRegistration: return "プロファイル登録を再試行"
        case .restoreDownloadForm: return "ダウンロードフォームを復元"
        case .copyURL: return "URLをコピー"
        case .copyTroubleshooting: return "トラブルシューティングをコピー"
        case .copySafety: return "安全性情報をコピー"
        }
    }

    func localizedDetail(language: AppLanguage) -> String {
        guard language.resolved == .japanese else {
            return detail
        }
        switch kind {
        case .openSettings: return "選択したバックエンドの実行ファイルパスを確認します。"
        case .openModels: return "モデル一覧で対象プロファイルを確認します。"
        case .openDownloads: return "ダウンロード状態と復元可能な設定を確認します。"
        case .openLogs: return "関連するエラーログを確認します。"
        case .editProfile: return "モデルパス、Model ID、またはポートを修正します。"
        case .checkPort: return "ポートの使用状況を再確認します。"
        case .runDiagnostics: return "セットアップと実行準備を確認します。"
        case .runReadyCheck: return "/v1/modelsの応答を再確認します。"
        case .retryDownload: return "失敗したダウンロードを元の設定で再試行します。"
        case .retryProfileRegistration: return "ダウンロード済みモデルを再利用してプロファイル登録だけを再試行します。"
        case .restoreDownloadForm: return "失敗したダウンロードの設定をフォームへ戻します。"
        case .copyURL: return "対象モデルのHugging Face URLをコピーします。"
        case .copyTroubleshooting: return "手動確認用の情報をコピーします。"
        case .copySafety: return "モデル操作の安全性情報をコピーします。"
        }
    }
}

struct RecoveryIssue: Identifiable, Hashable {
    var id: String { category.rawValue }
    let category: RecoveryIssueCategory
    let severity: RecoverySeverity
    let title: String
    let detail: String
    let relatedLogLine: String?
    let actions: [RecoveryAction]

    func localizedTitle(language: AppLanguage) -> String {
        category.localizedTitle(language: language)
    }

    func localizedDetail(language: AppLanguage) -> String {
        guard language.resolved == .japanese else {
            return detail
        }
        switch category {
        case .none:
            return "現在、復旧操作は必要ありません。"
        case .executableMissing:
            return "選択したバックエンドの実行ファイルパスを設定してください。"
        case .executableNotExecutable:
            return "実行ファイルの権限とパスを確認してください。"
        case .modelPathMissing:
            return "選択モデルのローカルパスまたはModel IDを確認してください。"
        case .portBusy:
            return "指定ポートは使用中です。競合するプロセスを確認するか、別のポートを選択してください。"
        case .permissionDenied:
            return "実行ファイルまたは保存先のアクセス権限を確認してください。"
        case .readinessTimeout:
            return "モデルのロード完了を待ってからReady確認を再実行してください。"
        case .processExitedEarly:
            return "プロセスが早期終了しました。ランタイムログを確認してください。"
        case .huggingFaceCLIMissing:
            return "Hugging Face CLIのインストール状態を確認してください。"
        case .huggingFaceAccess:
            return "モデルのアクセス権、ゲート承認、または認証状態を確認してください。"
        case .network:
            return "ネットワーク接続を確認してから再試行してください。"
        case .destination:
            return "保存先と空き容量、フォルダ権限を確認してください。"
        case .profileRegistration:
            return "ダウンロード済みモデルのプロファイル登録を再試行してください。"
        case .unknown:
            return "ログとトラブルシューティング情報を確認してください。"
        }
    }

    static let none = RecoveryIssue(
        category: .none,
        severity: .ok,
        title: RecoveryIssueCategory.none.title,
        detail: "No recovery action is currently needed.",
        relatedLogLine: nil,
        actions: []
    )
}
