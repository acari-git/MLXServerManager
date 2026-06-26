import SwiftUI

struct DashboardOverviewView: View {
    let targetSummary: ConnectionTargetSummary
    let runtimeState: ModelRuntimeState
    let selectedModel: ModelConfig?
    let exportSummaryText: String
    let memoryUsageText: String
    let selectedModelText: String
    let runningModelText: String
    let restartRequired: Bool
    var language: AppLanguage = .system

    private var l10n: AppLocalization {
        AppLocalization(language: language)
    }

    private func t(_ english: String, _ japanese: String) -> String {
        l10n.text(english: english, japanese: japanese)
    }

    var body: some View {
        DashboardSectionView(
            title: t("Dashboard v1", "ダッシュボード v1"),
            subtitle: t("Stable scan: next action, target/state, client setup, troubleshooting, then profile context. Lifecycle actions remain explicit below.", "安定運用向けの確認順です。次の操作、接続先と状態、クライアント設定、トラブルシューティング、プロファイル情報の順に確認します。ライフサイクル操作は下段で明示的に行います。")
        ) {
            VStack(alignment: .leading, spacing: 14) {
                DashboardGroupHeader(
                    title: t("1. Next action", "1. 次の操作"),
                    subtitle: t("Start here for the safest next step in the current state.", "現在の状態で最も安全な次の手順から確認します。")
                )

                DashboardNextStepsCard(
                    runtimeState: runtimeState,
                    targetSummary: targetSummary,
                    selectedModel: selectedModel,
                    language: language
                )
                .frame(maxWidth: .infinity, alignment: .topLeading)

                DashboardGroupHeader(
                    title: t("2. Target and state", "2. 接続先と状態"),
                    subtitle: t("Current Target explains connection context. Server State explains process, readiness, and lifecycle.", "現在の接続先は接続コンテキストを示します。サーバー状態はプロセス、準備状態、ライフサイクルを示します。")
                )

                HStack(alignment: .top, spacing: 12) {
                    DashboardCurrentTargetCard(
                        summary: targetSummary,
                        runtimeState: runtimeState,
                        language: language
                    )
                        .frame(maxWidth: .infinity, alignment: .topLeading)

                    DashboardServerStateCard(
                        runtimeState: runtimeState,
                        memoryUsageText: memoryUsageText,
                        selectedModelText: selectedModelText,
                        runningModelText: runningModelText,
                        restartRequired: restartRequired,
                        language: language
                    )
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }

                DashboardGroupHeader(
                    title: t("3. Client setup", "3. クライアント設定"),
                    subtitle: t("Use the active endpoint, model ID, and readiness state before pasting values into an OpenAI-compatible client.", "OpenAI互換クライアントへ値を貼り付ける前に、有効なエンドポイント、Model ID、準備状態を確認します。")
                )

                DashboardClientSetupCard(
                    runtimeState: runtimeState,
                    targetSummary: targetSummary,
                    selectedModel: selectedModel
                )
                .frame(maxWidth: .infinity, alignment: .topLeading)

                DashboardGroupHeader(
                    title: t("4. Troubleshooting", "4. トラブルシューティング"),
                    subtitle: t("Use diagnostics and logs when readiness, availability, or ownership is unclear.", "準備状態、利用可否、管理範囲が不明な場合は診断とログを確認します。")
                )

                DashboardDiagnosticsGuidanceCard(
                    runtimeState: runtimeState,
                    targetSummary: targetSummary
                )
                .frame(maxWidth: .infinity, alignment: .topLeading)

                DashboardGroupHeader(
                    title: t("5. Profile context", "5. プロファイル情報"),
                    subtitle: t("Profiles and Import / Export are metadata context, not lifecycle or model-file actions.", "プロファイルとインポート/エクスポートはメタデータのコンテキストであり、ライフサイクル操作やモデルファイル操作ではありません。")
                )

                DashboardProfileImportExportCard(
                    selectedModel: selectedModel,
                    targetSummary: targetSummary,
                    exportSummaryText: exportSummaryText
                )
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
    }
}

struct DashboardGroupHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 2)
        .accessibilityElement(children: .combine)
    }
}

struct DashboardSectionView<Content: View>: View {
    let title: String
    let subtitle: String
    let content: Content

    init(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct DashboardNextStepsCard: View {
    let runtimeState: ModelRuntimeState
    let targetSummary: ConnectionTargetSummary
    let selectedModel: ModelConfig?
    var language: AppLanguage = .system

    private var l10n: AppLocalization {
        AppLocalization(language: language)
    }

    private func t(_ english: String, _ japanese: String) -> String {
        l10n.text(english: english, japanese: japanese)
    }

    var body: some View {
        DashboardStatusCard(
            title: t("Next Steps", "次の手順"),
            systemImage: "list.bullet.clipboard",
            accentColor: display.accentColor
        ) {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(display.title)
                        .font(.callout.weight(.semibold))

                    Text(display.message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Divider()

                HStack(alignment: .top, spacing: 12) {
                    DashboardKeyValueRow(label: t("Primary Step", "主な手順"), value: display.primaryStep)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    DashboardKeyValueRow(label: t("Selected Profile", "選択プロファイル"), value: display.selectedProfile)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack(alignment: .top, spacing: 12) {
                    DashboardKeyValueRow(label: t("Managed Path", "管理サーバー経路"), value: display.managedPath)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    DashboardKeyValueRow(label: t("External Path", "外部サーバー経路"), value: display.externalPath)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack(alignment: .top, spacing: 12) {
                    DashboardKeyValueRow(label: t("Readiness", "準備状態"), value: display.readiness)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    DashboardKeyValueRow(label: "Direct Mode", value: display.directMode)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Label(display.safetyNote, systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var display: DashboardNextStepsDisplay {
        DashboardNextStepsDisplay(
            runtimeState: runtimeState,
            targetSummary: targetSummary,
            selectedModel: selectedModel,
            language: language
        )
    }
}

private struct DashboardNextStepsDisplay {
    let title: String
    let message: String
    let primaryStep: String
    let selectedProfile: String
    let managedPath: String
    let externalPath: String
    let readiness: String
    let directMode: String
    let safetyNote: String
    let accentColor: Color

    init(
        runtimeState: ModelRuntimeState,
        targetSummary: ConnectionTargetSummary,
        selectedModel: ModelConfig?,
        language: AppLanguage = .system
    ) {
        let l10n = AppLocalization(language: language)
        selectedProfile = Self.selectedProfileText(selectedModel, l10n: l10n)
        managedPath = Self.managedPathText(selectedModel, l10n: l10n)
        externalPath = l10n.text(english: "Adopt a detected external endpoint only when you want connection context; lifecycle and logs stay external.", japanese: "接続コンテキストが必要な場合のみ、検出された外部エンドポイントを採用します。ライフサイクルとログは外部管理のままです。")
        directMode = l10n.text(english: "\(targetSummary.directModeNote). No proxy or chat UI.", japanese: "\(targetSummary.directModeNote)。プロキシやチャットUIはありません。")

        switch runtimeState {
        case .stopped, .portAvailable:
            title = l10n.text(english: "Choose how to connect", japanese: "接続方法を選択")
            message = l10n.text(english: "Start a managed server from the selected profile, or adopt an already-running external server after it is detected.", japanese: "選択プロファイルから管理サーバーを起動するか、検出済みの実行中外部サーバーを採用します。")
            primaryStep = selectedModel == nil
                ? l10n.text(english: "Create, select, or import a profile before managed Start.", japanese: "管理サーバーを起動する前に、プロファイルを作成、選択、またはインポートしてください。")
                : l10n.text(english: "Run Diagnostics if needed, then press Start for a managed server.", japanese: "必要に応じて診断を実行し、管理サーバーを起動します。")
            readiness = l10n.text(english: "Ready appears after /v1/models responds successfully.", japanese: "/v1/modelsが正常応答するとReadyになります。")
            safetyNote = l10n.text(english: "Import Profiles restores metadata only; it does not download models or start servers.", japanese: "プロファイルのインポートはメタデータのみを復元します。モデルのダウンロードやサーバー起動は行いません。")
            accentColor = .blue
        case .externalServerDetected:
            title = l10n.text(english: "External endpoint is available", japanese: "外部エンドポイントを利用できます")
            message = l10n.text(english: "A compatible server responded on the selected endpoint, but it is not managed by MLX Server Manager.", japanese: "選択エンドポイントで互換サーバーが応答しましたが、MLX Server Managerの管理対象ではありません。")
            primaryStep = l10n.text(english: "Adopt External Server to use it as connection context, or leave it unmanaged.", japanese: "接続コンテキストとして使う場合は外部サーバーを採用します。不要なら外部管理のままにします。")
            readiness = l10n.text(english: "Detection is based on /v1/models responding successfully.", japanese: "検出は/v1/modelsの正常応答に基づきます。")
            safetyNote = l10n.text(english: "Adopt is never process ownership. Stop and Restart remain unavailable for this external process.", japanese: "採用はプロセス所有を意味しません。この外部プロセスでは停止と再起動は利用できません。")
            accentColor = .orange
        case .adoptedExternalServer:
            title = l10n.text(english: "External endpoint is adopted", japanese: "外部エンドポイントを採用済み")
            message = l10n.text(english: "Use Connection Settings for clients, or Forget External Server when this app-side context is no longer useful.", japanese: "クライアントには接続設定を使います。このアプリ側コンテキストが不要になったら外部サーバーを解除します。")
            primaryStep = l10n.text(english: "Copy Base URL, Model ID, API key placeholder, or client config.", japanese: "Base URL、Model ID、API Keyプレースホルダー、またはクライアント設定をコピーします。")
            readiness = l10n.text(english: "Readiness describes endpoint response, not external process ownership.", japanese: "準備状態はエンドポイント応答を示すもので、外部プロセスの所有を示しません。")
            safetyNote = l10n.text(english: "Forget External Server clears context only and does not stop the server.", japanese: "外部サーバー解除はコンテキストだけを消去し、サーバーは停止しません。")
            accentColor = .orange
        case .starting, .loading, .checkingReady:
            title = l10n.text(english: "Wait for readiness", japanese: "Readyを待機")
            message = l10n.text(english: "The target is not ready until /v1/models responds successfully.", japanese: "/v1/modelsが正常応答するまでは接続先はReadyではありません。")
            primaryStep = l10n.text(english: "Watch state and logs before pointing clients at the endpoint.", japanese: "クライアントをエンドポイントへ向ける前に、状態とログを確認してください。")
            readiness = l10n.text(english: "Running and Ready are separate states.", japanese: "RunningとReadyは別の状態です。")
            safetyNote = l10n.text(english: "The app does not send inference requests, auto-restart, or kill processes while waiting.", japanese: "待機中に推論リクエスト送信、自動再起動、プロセスkillは行いません。")
            accentColor = .orange
        case let .ready(_, _, processIdentifier):
            if processIdentifier != nil {
                title = l10n.text(english: "Managed server is ready", japanese: "管理サーバーはReadyです")
                message = l10n.text(english: "The selected managed endpoint is ready for OpenAI-compatible clients.", japanese: "選択された管理エンドポイントはOpenAI互換クライアントで利用できます。")
                primaryStep = l10n.text(english: "Copy connection settings and paste them into your client.", japanese: "接続設定をコピーしてクライアントへ貼り付けます。")
                safetyNote = l10n.text(english: "Stop and Restart affect only this app-managed process.", japanese: "停止と再起動は、このアプリ管理プロセスのみに影響します。")
            } else {
                title = l10n.text(english: "Endpoint is ready", japanese: "エンドポイントはReadyです")
                message = l10n.text(english: "The endpoint responded to readiness, but no app-managed pid is attached.", japanese: "エンドポイントはReady確認に応答しましたが、アプリ管理pidは付いていません。")
                primaryStep = l10n.text(english: "Use connection settings and verify process ownership outside the app.", japanese: "接続設定を使い、プロセス所有権はアプリ外で確認してください。")
                safetyNote = l10n.text(english: "The app does not infer ownership from readiness alone.", japanese: "アプリはReadyだけで所有権を推定しません。")
            }
            readiness = "Ready means /v1/models responded successfully."
            accentColor = .green
        case .stopping:
            title = l10n.text(english: "Managed server is stopping", japanese: "管理サーバーを停止中")
            message = l10n.text(english: "The app is stopping only the app-managed process.", japanese: "アプリ管理プロセスのみを停止しています。")
            primaryStep = l10n.text(english: "Wait for stopped state before starting again or changing runtime expectations.", japanese: "再起動やランタイム想定の変更前に、停止状態になるまで待機してください。")
            readiness = l10n.text(english: "Readiness is unavailable while stopping.", japanese: "停止中はReady確認を利用できません。")
            safetyNote = l10n.text(english: "External servers are not affected by managed Stop.", japanese: "管理サーバー停止は外部サーバーに影響しません。")
            accentColor = .orange
        case .checkingPort:
            title = l10n.text(english: "Checking endpoint availability", japanese: "エンドポイント利用可否を確認中")
            message = l10n.text(english: "The app is checking whether the selected host and port can be used safely.", japanese: "選択したホストとポートを安全に利用できるか確認しています。")
            primaryStep = l10n.text(english: "Wait for the port check result before pressing Start.", japanese: "起動前にポート確認結果を待ってください。")
            readiness = l10n.text(english: "Port availability is not readiness.", japanese: "ポート利用可否はReady状態ではありません。")
            safetyNote = l10n.text(english: "Port checks do not start, stop, adopt, or inspect external processes.", japanese: "ポート確認は外部プロセスの起動、停止、採用、検査を行いません。")
            accentColor = .orange
        case .portBusy:
            title = "Endpoint needs attention"
            message = "The selected port is busy. Confirm whether it is the server you intend to use."
            primaryStep = "Change port, stop your own external server manually, or adopt only after detection confirms compatibility."
            readiness = "Busy does not mean ready; /v1/models must respond."
            safetyNote = "The app does not kill or take ownership of busy external processes."
            accentColor = .red
        case .portCheckFailed, .readyCheckFailed, .error:
            title = "Check setup and logs"
            message = "The current state needs manual review before clients rely on this endpoint."
            primaryStep = "Check host, port, selected profile, diagnostics, and available logs."
            readiness = "Readiness has not been confirmed."
            safetyNote = "No automatic restart, cleanup, model download, or process takeover is attempted."
            accentColor = .red
        case .unknown:
            title = "State is unclear"
            message = "The app cannot confidently describe what should happen next."
            primaryStep = "Review logs, rerun diagnostics, or check readiness manually."
            readiness = "Unknown until a check succeeds or fails clearly."
            safetyNote = "Unknown state does not trigger automatic lifecycle actions."
            accentColor = .yellow
        }
    }

    private static func selectedProfileText(_ selectedModel: ModelConfig?, l10n: AppLocalization) -> String {
        guard let selectedModel else {
            return l10n.text(english: "No selected profile. Create, select, or import profile metadata first.", japanese: "選択プロファイルがありません。先にプロファイルメタデータを作成、選択、またはインポートしてください。")
        }

        let displayName = selectedModel.displayName.isEmpty
            ? selectedModel.modelID
            : selectedModel.displayName
        return "\(displayName) - \(selectedModel.modelID)"
    }

    private static func managedPathText(_ selectedModel: ModelConfig?, l10n: AppLocalization) -> String {
        guard let selectedModel else {
            return l10n.text(english: "Managed Start needs a selected profile with model ID, host, and port.", japanese: "管理サーバーの起動には、Model ID、ホスト、ポートを含む選択プロファイルが必要です。")
        }

        return l10n.text(english: "Start launches app-managed mlx_lm.server using \(selectedModel.host):\(selectedModel.serverPort).", japanese: "起動すると、\(selectedModel.host):\(selectedModel.serverPort) を使ってアプリ管理のmlx_lm.serverを起動します。")
    }
}

struct DashboardCurrentTargetCard: View {
    let summary: ConnectionTargetSummary
    let runtimeState: ModelRuntimeState
    var language: AppLanguage = .system

    private var l10n: AppLocalization {
        AppLocalization(language: language)
    }

    private func t(_ english: String, _ japanese: String) -> String {
        l10n.text(english: english, japanese: japanese)
    }

    var body: some View {
        DashboardStatusCard(
            title: t("Current Target", "現在の接続先"),
            systemImage: display.iconName,
            accentColor: display.accentColor
        ) {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(display.title)
                        .font(.callout.weight(.semibold))

                    Text(display.message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Divider()

                DashboardKeyValueRow(label: t("Target Type", "接続先タイプ"), value: display.targetType)
                DashboardKeyValueRow(label: t("Endpoint", "エンドポイント"), value: display.endpoint)
                DashboardKeyValueRow(label: t("Selected Model", "選択モデル"), value: display.modelID)
                DashboardKeyValueRow(label: t("Readiness", "準備状態"), value: display.readiness)
                DashboardKeyValueRow(label: t("Ownership", "管理範囲"), value: display.ownership)

                if let lifecycleNote = display.lifecycleNote {
                    Label(lifecycleNote, systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text(summary.directModeNote)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            }
        }
    }

    private var display: DashboardCurrentTargetDisplay {
        DashboardCurrentTargetDisplay(summary: summary, runtimeState: runtimeState, language: language)
    }
}

private struct DashboardCurrentTargetDisplay {
    let title: String
    let message: String
    let targetType: String
    let endpoint: String
    let modelID: String
    let readiness: String
    let ownership: String
    let lifecycleNote: String?
    let iconName: String
    let accentColor: Color

    init(summary: ConnectionTargetSummary, runtimeState: ModelRuntimeState, language: AppLanguage = .system) {
        let l10n = AppLocalization(language: language)
        self.modelID = summary.modelID

        switch runtimeState {
        case let .externalServerDetected(host, port, baseURL, _):
            title = l10n.text(english: "External server detected", japanese: "外部サーバーを検出")
            message = l10n.text(english: "A compatible endpoint responded on the selected host and port. It is not managed until you explicitly adopt it as connection context.", japanese: "選択したホストとポートで互換エンドポイントが応答しました。接続コンテキストとして明示的に採用するまでは管理対象ではありません。")
            targetType = l10n.text(english: "External Server Detected", japanese: "検出済み外部サーバー")
            endpoint = "\(baseURL) (\(host):\(port))"
            readiness = l10n.text(english: "Ready - /v1/models responded successfully", japanese: "Ready - /v1/modelsが正常応答")
            ownership = l10n.text(english: "External server, not owned by MLX Server Manager", japanese: "外部サーバー。MLX Server Managerの所有ではありません。")
            lifecycleNote = l10n.text(english: "Adopt is connection context only. Stop and Restart remain unavailable for this external process.", japanese: "採用は接続コンテキストのみです。この外部プロセスでは停止と再起動は利用できません。")
            iconName = "network"
            accentColor = .orange
        case let .adoptedExternalServer(host, port, baseURL, _):
            title = l10n.text(english: "Adopted external server", japanese: "採用済み外部サーバー")
            message = l10n.text(english: "This endpoint is being used as connection context only. MLX Server Manager does not own or control the process.", japanese: "このエンドポイントは接続コンテキストとしてのみ使用中です。MLX Server Managerはプロセスを所有・制御しません。")
            targetType = l10n.text(english: "Adopted External Server", japanese: "採用済み外部サーバー")
            endpoint = "\(baseURL) (\(host):\(port))"
            readiness = l10n.text(english: "Ready - /v1/models responded successfully", japanese: "Ready - /v1/modelsが正常応答")
            ownership = l10n.text(english: "Connection context only", japanese: "接続コンテキストのみ")
            lifecycleNote = l10n.text(english: "Forget External Server only clears app-side context. It does not stop the server.", japanese: "外部サーバー解除はアプリ側コンテキストのみを消去します。サーバーは停止しません。")
            iconName = "link"
            accentColor = .orange
        case let .ready(host, port, processIdentifier):
            title = l10n.text(english: "Managed server ready", japanese: "管理サーバーはReadyです")
            message = l10n.text(english: "The selected endpoint is ready for an OpenAI-compatible client. MLX Server Manager owns this managed process when a pid is attached.", japanese: "選択エンドポイントはOpenAI互換クライアントで利用できます。pidが付いている場合、この管理プロセスはMLX Server Managerの所有です。")
            targetType = l10n.text(english: "Managed Server", japanese: "管理サーバー")
            endpoint = "\(summary.baseURL) (\(host):\(port))"
            readiness = l10n.text(english: "Ready - /v1/models responded successfully", japanese: "Ready - /v1/modelsが正常応答")
            if let processIdentifier {
                ownership = l10n.text(english: "Managed by MLX Server Manager, pid \(processIdentifier)", japanese: "MLX Server Managerが管理中、pid \(processIdentifier)")
            } else {
                ownership = l10n.text(english: "Ready endpoint, no managed pid attached", japanese: "Readyエンドポイントですが、管理pidは付いていません")
            }
            lifecycleNote = l10n.text(english: "Start, Stop, and Restart controls apply only when an app-managed process is attached.", japanese: "起動、停止、再起動はアプリ管理プロセスが付いている場合のみ適用されます。")
            iconName = "server.rack"
            accentColor = .green
        case let .starting(host, port):
            title = l10n.text(english: "Managed server starting", japanese: "管理サーバーを起動中")
            message = l10n.text(english: "A managed launch is in progress. Readiness has not completed yet.", japanese: "管理起動を実行中です。Ready確認はまだ完了していません。")
            targetType = l10n.text(english: "Managed Server", japanese: "管理サーバー")
            endpoint = "\(summary.baseURL) (\(host):\(port))"
            readiness = l10n.text(english: "Not checked - waiting for /v1/models", japanese: "未確認 - /v1/modelsを待機中")
            ownership = l10n.text(english: "Managed launch requested by MLX Server Manager", japanese: "MLX Server Managerが管理起動を要求済み")
            lifecycleNote = l10n.text(english: "Lifecycle actions remain explicit; no automatic restart is triggered by this card.", japanese: "ライフサイクル操作は明示的な操作のままです。このカードが自動再起動を起動することはありません。")
            iconName = "server.rack"
            accentColor = .orange
        case let .loading(host, port, processIdentifier):
            title = l10n.text(english: "Managed server loading", japanese: "管理サーバーをロード中")
            message = l10n.text(english: "A managed process is attached and the endpoint is still loading.", japanese: "管理プロセスが付いており、エンドポイントはまだロード中です。")
            targetType = l10n.text(english: "Managed Server", japanese: "管理サーバー")
            endpoint = "\(summary.baseURL) (\(host):\(port))"
            readiness = l10n.text(english: "Checking - waiting for /v1/models", japanese: "確認中 - /v1/modelsを待機中")
            ownership = l10n.text(english: "Managed by MLX Server Manager, pid \(processIdentifier)", japanese: "MLX Server Managerが管理中、pid \(processIdentifier)")
            lifecycleNote = l10n.text(english: "Stop and Restart apply to the managed process only.", japanese: "停止と再起動は管理プロセスのみに適用されます。")
            iconName = "server.rack"
            accentColor = .orange
        case let .checkingReady(host, port):
            title = l10n.text(english: "Checking readiness", japanese: "Ready確認中")
            message = l10n.text(english: "The app is checking the selected endpoint with /v1/models.", japanese: "アプリが/v1/modelsで選択エンドポイントを確認しています。")
            targetType = summary.targetType
            endpoint = "\(summary.baseURL) (\(host):\(port))"
            readiness = l10n.text(english: "Checking - /v1/models request in progress", japanese: "確認中 - /v1/modelsリクエスト実行中")
            ownership = summary.ownershipNote
            lifecycleNote = l10n.text(english: "Readiness check does not send inference requests.", japanese: "Ready確認では推論リクエストを送信しません。")
            iconName = summary.isActiveTarget ? "server.rack" : "power"
            accentColor = .orange
        case let .readyCheckFailed(host, port, message):
            title = l10n.text(english: "Target readiness failed", japanese: "接続先のReady確認に失敗")
            self.message = l10n.text(english: "The selected endpoint did not pass the /v1/models readiness check: \(message)", japanese: "選択エンドポイントは/v1/modelsのReady確認に合格しませんでした: \(message)")
            targetType = summary.targetType
            endpoint = "\(summary.baseURL) (\(host):\(port))"
            readiness = l10n.text(english: "Failed - readiness check failed", japanese: "失敗 - Ready確認失敗")
            ownership = summary.ownershipNote
            lifecycleNote = l10n.text(english: "No automatic recovery is attempted. Use existing controls after checking setup and logs.", japanese: "自動復旧は試行しません。設定とログを確認してから既存の操作を使ってください。")
            iconName = "exclamationmark.triangle"
            accentColor = .red
        case let .portBusy(host, port):
            title = l10n.text(english: "Endpoint unavailable", japanese: "エンドポイントを利用できません")
            message = l10n.text(english: "The selected host and port are busy, but no target has been adopted or attached here.", japanese: "選択したホストとポートは使用中ですが、ここでは接続先の採用や接続は行われていません。")
            targetType = l10n.text(english: "Unavailable", japanese: "利用不可")
            endpoint = "\(summary.baseURL) (\(host):\(port))"
            readiness = l10n.text(english: "Unavailable - port is busy", japanese: "利用不可 - ポート使用中")
            ownership = l10n.text(english: "No app-managed process attached", japanese: "アプリ管理プロセスは付いていません")
            lifecycleNote = l10n.text(english: "Start will not launch a second server on this port.", japanese: "このポートで2つ目のサーバーを起動することはありません。")
            iconName = "exclamationmark.triangle"
            accentColor = .red
        case let .portCheckFailed(host, port, message):
            title = l10n.text(english: "Endpoint check failed", japanese: "エンドポイント確認に失敗")
            self.message = l10n.text(english: "The selected endpoint could not be checked: \(message)", japanese: "選択エンドポイントを確認できませんでした: \(message)")
            targetType = l10n.text(english: "Unavailable", japanese: "利用不可")
            endpoint = "\(summary.baseURL) (\(host):\(port))"
            readiness = l10n.text(english: "Failed - endpoint check failed", japanese: "失敗 - エンドポイント確認失敗")
            ownership = l10n.text(english: "No app-managed process attached", japanese: "アプリ管理プロセスは付いていません")
            lifecycleNote = l10n.text(english: "No automatic recovery is attempted.", japanese: "自動復旧は試行しません。")
            iconName = "exclamationmark.triangle"
            accentColor = .red
        case let .checkingPort(host, port):
            title = l10n.text(english: "Checking endpoint", japanese: "エンドポイント確認中")
            message = l10n.text(english: "The app is checking whether the selected host and port can be used.", japanese: "選択したホストとポートを利用できるか確認しています。")
            targetType = l10n.text(english: "No Current Target", japanese: "現在の接続先なし")
            endpoint = "\(summary.baseURL) (\(host):\(port))"
            readiness = l10n.text(english: "Not checked - port check in progress", japanese: "未確認 - ポート確認中")
            ownership = l10n.text(english: "No app-managed process attached", japanese: "アプリ管理プロセスは付いていません")
            lifecycleNote = l10n.text(english: "Port checks do not start or stop servers.", japanese: "ポート確認はサーバーの起動や停止を行いません。")
            iconName = "power"
            accentColor = .orange
        case let .portAvailable(host, port):
            title = l10n.text(english: "No current target", japanese: "現在の接続先なし")
            message = l10n.text(english: "The selected host and port are available. Start a managed server or adopt an external server through the existing controls.", japanese: "選択したホストとポートは利用可能です。既存の操作から管理サーバーを起動するか、外部サーバーを採用してください。")
            targetType = l10n.text(english: "No Current Target", japanese: "現在の接続先なし")
            endpoint = "\(summary.baseURL) (\(host):\(port))"
            readiness = l10n.text(english: "Not checked - no active target", japanese: "未確認 - 有効な接続先なし")
            ownership = l10n.text(english: "No app-managed process attached", japanese: "アプリ管理プロセスは付いていません")
            lifecycleNote = l10n.text(english: "Start remains an explicit user action.", japanese: "起動は明示的なユーザー操作のままです。")
            iconName = "power"
            accentColor = .secondary
        case .stopped:
            title = l10n.text(english: "No current target", japanese: "現在の接続先なし")
            message = l10n.text(english: "No managed server is running and no external server is adopted.", japanese: "管理サーバーは実行されておらず、外部サーバーも採用されていません。")
            targetType = l10n.text(english: "No Current Target", japanese: "現在の接続先なし")
            endpoint = summary.baseURL
            readiness = l10n.text(english: "Not checked - no active target", japanese: "未確認 - 有効な接続先なし")
            ownership = l10n.text(english: "No app-managed process attached", japanese: "アプリ管理プロセスは付いていません")
            lifecycleNote = l10n.text(english: "Start a managed server, or adopt a detected external server after readiness succeeds.", japanese: "管理サーバーを起動するか、Ready確認後に検出済み外部サーバーを採用してください。")
            iconName = "power"
            accentColor = .secondary
        case .stopping:
            title = l10n.text(english: "Managed server stopping", japanese: "管理サーバーを停止中")
            message = l10n.text(english: "The app-managed process is stopping. The current target is becoming unavailable.", japanese: "アプリ管理プロセスを停止中です。現在の接続先は利用不可になります。")
            targetType = l10n.text(english: "Managed Server", japanese: "管理サーバー")
            endpoint = summary.baseURL
            readiness = l10n.text(english: "Unavailable - process is stopping", japanese: "利用不可 - プロセス停止中")
            ownership = l10n.text(english: "Managed process is stopping", japanese: "管理プロセスを停止中")
            lifecycleNote = l10n.text(english: "Stop applies only to the app-managed process.", japanese: "停止はアプリ管理プロセスのみに適用されます。")
            iconName = "server.rack"
            accentColor = .orange
        case let .error(message), let .unknown(message):
            title = l10n.text(english: "Target state needs attention", japanese: "接続先状態の確認が必要")
            self.message = message
            targetType = summary.isActiveTarget ? summary.targetType : l10n.text(english: "Unavailable", japanese: "利用不可")
            endpoint = summary.baseURL
            readiness = l10n.text(english: "Unavailable - check status and logs", japanese: "利用不可 - 状態とログを確認してください")
            ownership = summary.ownershipNote
            lifecycleNote = l10n.text(english: "No automatic recovery is attempted.", japanese: "自動復旧は試行しません。")
            iconName = "exclamationmark.triangle"
            accentColor = .red
        }
    }
}

struct DashboardClientSetupCard: View {
    let runtimeState: ModelRuntimeState
    let targetSummary: ConnectionTargetSummary
    let selectedModel: ModelConfig?
    var language: AppLanguage = .system

    private var l10n: AppLocalization {
        AppLocalization(language: language)
    }

    private func t(_ english: String, _ japanese: String) -> String {
        l10n.text(english: english, japanese: japanese)
    }

    var body: some View {
        DashboardStatusCard(
            title: t("Client Setup", "クライアント設定"),
            systemImage: "doc.on.clipboard",
            accentColor: display.accentColor
        ) {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(display.title)
                        .font(.callout.weight(.semibold))

                    Text(display.message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Divider()

                HStack(alignment: .top, spacing: 12) {
                    DashboardKeyValueRow(label: t("Client Base URL", "クライアントBase URL"), value: display.clientBaseURL)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    DashboardKeyValueRow(label: t("Model ID Guidance", "Model IDガイド"), value: display.modelIDGuidance)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack(alignment: .top, spacing: 12) {
                    DashboardKeyValueRow(label: t("Endpoint Source", "エンドポイント元"), value: display.endpointSource)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    DashboardKeyValueRow(label: t("Readiness Before Client Use", "利用前のReady確認"), value: display.readinessGuidance)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack(alignment: .top, spacing: 12) {
                    DashboardKeyValueRow(label: t("Profile Endpoint", "プロファイルエンドポイント"), value: display.profileEndpoint)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    DashboardKeyValueRow(label: t("Copy From", "コピー元"), value: display.copyGuidance)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Label(display.safetyNote, systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var display: DashboardClientSetupDisplay {
        DashboardClientSetupDisplay(
            runtimeState: runtimeState,
            targetSummary: targetSummary,
            selectedModel: selectedModel,
            language: language
        )
    }
}

private struct DashboardClientSetupDisplay {
    let title: String
    let message: String
    let clientBaseURL: String
    let modelIDGuidance: String
    let endpointSource: String
    let readinessGuidance: String
    let profileEndpoint: String
    let copyGuidance: String
    let safetyNote: String
    let accentColor: Color

    init(
        runtimeState: ModelRuntimeState,
        targetSummary: ConnectionTargetSummary,
        selectedModel: ModelConfig?,
        language: AppLanguage = .system
    ) {
        let l10n = AppLocalization(language: language)
        let selectedProfileEndpoint = selectedModel.map { "http://\($0.host):\($0.serverPort)/v1" }
        profileEndpoint = selectedProfileEndpoint ?? l10n.text(english: "No selected profile endpoint", japanese: "選択プロファイルのエンドポイントなし")

        let activeEndpoint = Self.activeEndpointText(
            runtimeState: runtimeState,
            fallbackBaseURL: targetSummary.baseURL
        )
        let activeRelationship = Self.activeRelationshipText(
            activeEndpoint: activeEndpoint,
            profileEndpoint: selectedProfileEndpoint,
            targetSummary: targetSummary,
            l10n: l10n
        )

        modelIDGuidance = Self.modelIDGuidanceText(
            selectedModel: selectedModel,
            targetSummary: targetSummary,
            l10n: l10n
        )
        copyGuidance = l10n.text(english: "Use Connection Settings to copy Base URL, Model ID, API key placeholder, JSON config, Hermes Agent config, or curl readiness command.", japanese: "接続設定からBase URL、Model ID、API Keyプレースホルダー、JSON設定、Hermes Agent設定、またはReady確認curlをコピーします。")
        safetyNote = l10n.text(english: "Direct Mode means clients connect directly to the active server endpoint. MLX Server Manager does not proxy inference requests or store API keys or tokens.", japanese: "Direct Modeではクライアントが有効なサーバーエンドポイントへ直接接続します。MLX Server Managerは推論リクエストをプロキシせず、APIキーやトークンも保存しません。")

        switch runtimeState {
        case let .externalServerDetected(_, _, baseURL, _):
            title = l10n.text(english: "Detected external endpoint", japanese: "検出済み外部エンドポイント")
            message = l10n.text(english: "Adopt this endpoint only if you want MLX Server Manager to show it as connection context for client setup.", japanese: "このエンドポイントをクライアント設定用の接続コンテキストとして表示したい場合のみ採用します。")
            clientBaseURL = baseURL
            endpointSource = l10n.text(english: "Detected external server. \(activeRelationship)", japanese: "検出済み外部サーバー。\(activeRelationship)")
            readinessGuidance = l10n.text(english: "Ready means /v1/models responded successfully. External lifecycle and logs stay outside the app.", japanese: "Readyは/v1/modelsが正常応答したことを意味します。外部サーバーのライフサイクルとログはアプリ外にあります。")
            accentColor = .orange
        case let .adoptedExternalServer(_, _, baseURL, _):
            title = l10n.text(english: "Use the adopted endpoint", japanese: "採用済みエンドポイントを使用")
            message = l10n.text(english: "OpenAI-compatible clients should point directly at the adopted external server.", japanese: "OpenAI互換クライアントは採用済み外部サーバーを直接参照します。")
            clientBaseURL = baseURL
            endpointSource = l10n.text(english: "Adopted external connection context only. \(activeRelationship)", japanese: "採用済み外部接続コンテキストのみ。\(activeRelationship)")
            readinessGuidance = l10n.text(english: "Use the external server's exposed model names when they differ from selected profile metadata.", japanese: "外部サーバーが選択プロファイルのメタデータと異なるモデル名を公開している場合は、その公開名を使います。")
            accentColor = .orange
        case let .ready(_, _, processIdentifier):
            title = l10n.text(english: "Copy the ready endpoint", japanese: "Readyエンドポイントをコピー")
            message = l10n.text(english: "The current endpoint passed readiness and can be used by an OpenAI-compatible client.", japanese: "現在のエンドポイントはReady確認に合格しており、OpenAI互換クライアントで利用できます。")
            clientBaseURL = activeEndpoint ?? targetSummary.baseURL
            if processIdentifier != nil {
                endpointSource = l10n.text(english: "App-managed server. \(activeRelationship)", japanese: "アプリ管理サーバー。\(activeRelationship)")
            } else {
                endpointSource = l10n.text(english: "Ready endpoint without managed pid. \(activeRelationship)", japanese: "管理pidなしのReadyエンドポイント。\(activeRelationship)")
            }
            readinessGuidance = l10n.text(english: "Ready means /v1/models responded successfully before client setup.", japanese: "クライアント設定前のReadyは、/v1/modelsが正常応答したことを意味します。")
            accentColor = .green
        case .starting, .loading, .checkingReady:
            title = l10n.text(english: "Wait before client setup", japanese: "クライアント設定前に待機")
            message = l10n.text(english: "A target is starting or being checked; wait for Ready before expecting clients to work.", japanese: "接続先が起動中または確認中です。クライアント利用前にReadyを待ってください。")
            clientBaseURL = activeEndpoint ?? targetSummary.baseURL
            endpointSource = l10n.text(english: "Pending target. \(activeRelationship)", japanese: "保留中の接続先。\(activeRelationship)")
            readinessGuidance = l10n.text(english: "Do not treat process startup as readiness; wait for /v1/models success.", japanese: "プロセス起動をReadyとは扱わず、/v1/modelsの成功を待ってください。")
            accentColor = .orange
        case .stopped, .portAvailable:
            title = l10n.text(english: "No active endpoint yet", japanese: "有効なエンドポイントはまだありません")
            message = l10n.text(english: "Start a managed server or adopt a detected external server before using client connection values.", japanese: "クライアント接続値を使う前に、管理サーバーを起動するか、検出済み外部サーバーを採用してください。")
            clientBaseURL = l10n.text(english: "No active endpoint", japanese: "有効なエンドポイントなし")
            endpointSource = l10n.text(english: "Selected profile endpoint is saved configuration only. \(activeRelationship)", japanese: "選択プロファイルのエンドポイントは保存済み設定のみです。\(activeRelationship)")
            readinessGuidance = l10n.text(english: "Readiness is not checked until a server target exists.", japanese: "サーバー接続先が存在するまでReady確認は行われません。")
            accentColor = .secondary
        case .portBusy, .portCheckFailed, .readyCheckFailed, .error, .unknown:
            title = l10n.text(english: "Check endpoint before copying", japanese: "コピー前にエンドポイントを確認")
            message = l10n.text(english: "The current endpoint is unavailable, failed, or unclear. Verify state before pasting values into a client.", japanese: "現在のエンドポイントは利用不可、失敗、または不明です。クライアントへ貼り付ける前に状態を確認してください。")
            clientBaseURL = activeEndpoint ?? targetSummary.baseURL
            endpointSource = l10n.text(english: "Endpoint needs review. \(activeRelationship)", japanese: "エンドポイントの確認が必要です。\(activeRelationship)")
            readinessGuidance = l10n.text(english: "Use Diagnostics, logs, and /v1/models readiness before relying on client setup.", japanese: "クライアント設定に依存する前に、診断、ログ、/v1/modelsのReady確認を使ってください。")
            accentColor = .red
        case .checkingPort:
            title = l10n.text(english: "Endpoint check in progress", japanese: "エンドポイント確認中")
            message = l10n.text(english: "The selected host and port are being checked; this does not create an active client target.", japanese: "選択したホストとポートを確認中です。これにより有効なクライアント接続先が作られるわけではありません。")
            clientBaseURL = activeEndpoint ?? targetSummary.baseURL
            endpointSource = l10n.text(english: "Port check only. \(activeRelationship)", japanese: "ポート確認のみ。\(activeRelationship)")
            readinessGuidance = l10n.text(english: "Port availability is not readiness.", japanese: "ポート利用可否はReady状態ではありません。")
            accentColor = .orange
        case .stopping:
            title = l10n.text(english: "Endpoint is stopping", japanese: "エンドポイント停止中")
            message = l10n.text(english: "Wait for the managed stop to complete before copying client connection values.", japanese: "クライアント接続値をコピーする前に、管理停止が完了するまで待ってください。")
            clientBaseURL = activeEndpoint ?? targetSummary.baseURL
            endpointSource = l10n.text(english: "Managed process is stopping. \(activeRelationship)", japanese: "管理プロセスを停止中です。\(activeRelationship)")
            readinessGuidance = l10n.text(english: "The endpoint should be treated as unavailable while stopping.", japanese: "停止中のエンドポイントは利用不可として扱ってください。")
            accentColor = .orange
        }
    }

    private static func activeEndpointText(
        runtimeState: ModelRuntimeState,
        fallbackBaseURL: String
    ) -> String? {
        switch runtimeState {
        case let .externalServerDetected(_, _, baseURL, _):
            return baseURL
        case let .adoptedExternalServer(_, _, baseURL, _):
            return baseURL
        case .stopped, .portAvailable:
            return nil
        default:
            return fallbackBaseURL
        }
    }

    private static func activeRelationshipText(
        activeEndpoint: String?,
        profileEndpoint: String?,
        targetSummary: ConnectionTargetSummary,
        l10n: AppLocalization
    ) -> String {
        guard let activeEndpoint else {
            return l10n.text(english: "No active target is available yet.", japanese: "有効な接続先はまだありません。")
        }

        guard let profileEndpoint else {
            return l10n.text(english: "No selected profile endpoint is available.", japanese: "選択プロファイルのエンドポイントはありません。")
        }

        if activeEndpoint == profileEndpoint {
            return l10n.text(english: "Active endpoint matches the selected profile endpoint.", japanese: "有効なエンドポイントは選択プロファイルのエンドポイントと一致しています。")
        }

        if targetSummary.targetType.localizedCaseInsensitiveContains("external") {
            return l10n.text(english: "Adopted or detected external endpoint may differ from selected profile metadata.", japanese: "採用または検出された外部エンドポイントは、選択プロファイルのメタデータと異なる場合があります。")
        }

        return l10n.text(english: "Active endpoint and saved profile endpoint differ; check selected/running model state.", japanese: "有効なエンドポイントと保存済みプロファイルのエンドポイントが異なります。選択中/実行中モデルの状態を確認してください。")
    }

    private static func modelIDGuidanceText(
        selectedModel: ModelConfig?,
        targetSummary: ConnectionTargetSummary,
        l10n: AppLocalization
    ) -> String {
        guard let selectedModel else {
            return l10n.text(english: "No selected profile model ID. Use the model name exposed by the active server.", japanese: "選択プロファイルのModel IDがありません。有効なサーバーが公開しているモデル名を使ってください。")
        }

        if targetSummary.targetType.localizedCaseInsensitiveContains("external") {
            return l10n.text(english: "Selected profile model ID: \(selectedModel.modelID). External servers may expose a different model name.", japanese: "選択プロファイルのModel ID: \(selectedModel.modelID)。外部サーバーは異なるモデル名を公開している場合があります。")
        }

        return l10n.text(english: "Use selected profile model ID: \(selectedModel.modelID). If a client rejects it, check /v1/models or server logs.", japanese: "選択プロファイルのModel IDを使います: \(selectedModel.modelID)。クライアントが拒否する場合は/v1/modelsまたはサーバーログを確認してください。")
    }
}

struct DashboardServerStateCard: View {
    let runtimeState: ModelRuntimeState
    let memoryUsageText: String
    let selectedModelText: String
    let runningModelText: String
    let restartRequired: Bool
    var language: AppLanguage = .system

    private var l10n: AppLocalization {
        AppLocalization(language: language)
    }

    private func t(_ english: String, _ japanese: String) -> String {
        l10n.text(english: english, japanese: japanese)
    }

    var body: some View {
        DashboardStatusCard(
            title: t("Server State", "サーバー状態"),
            systemImage: "gauge",
            accentColor: display.accentColor
        ) {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(display.title)
                        .font(.callout.weight(.semibold))

                    Text(display.message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Divider()

                DashboardKeyValueRow(label: t("Process State", "プロセス状態"), value: display.processState)
                DashboardKeyValueRow(label: t("Readiness", "準備状態"), value: display.readiness)
                DashboardKeyValueRow(label: t("Lifecycle", "ライフサイクル"), value: display.lifecycle)
                DashboardKeyValueRow(label: t("Memory", "メモリ"), value: display.memory)

                Text(selectedModelText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Text(runningModelText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                if restartRequired {
                    Label(t("Restart required to apply selected model.", "選択モデルを反映するには再起動が必要です。"), systemImage: "arrow.clockwise.circle")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                        .padding(.top, 2)
                }

                Label(display.lifecycleNote, systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var display: DashboardServerStateDisplay {
        DashboardServerStateDisplay(
            runtimeState: runtimeState,
            memoryUsageText: memoryUsageText,
            language: language
        )
    }
}

private struct DashboardServerStateDisplay {
    let title: String
    let message: String
    let processState: String
    let readiness: String
    let lifecycle: String
    let memory: String
    let lifecycleNote: String
    let accentColor: Color

    init(runtimeState: ModelRuntimeState, memoryUsageText: String, language: AppLanguage = .system) {
        let l10n = AppLocalization(language: language)
        self.memory = memoryUsageText.replacingOccurrences(of: "Memory: ", with: "")

        switch runtimeState {
        case .stopped:
            title = l10n.text(english: "No server process attached", japanese: "サーバープロセス未接続")
            message = l10n.text(english: "No app-managed process is running and no external server context is active.", japanese: "アプリ管理プロセスは実行されておらず、外部サーバーコンテキストも有効ではありません。")
            processState = l10n.text(english: "Stopped", japanese: "停止中")
            readiness = l10n.text(english: "Unavailable - no active server target", japanese: "利用不可 - 有効なサーバー接続先なし")
            lifecycle = l10n.text(english: "Start is available through the existing controls", japanese: "既存の操作から起動できます")
            lifecycleNote = l10n.text(english: "Starting a managed server is always an explicit user action.", japanese: "管理サーバーの起動は常に明示的なユーザー操作です。")
            accentColor = .secondary
        case let .starting(host, port):
            title = l10n.text(english: "Managed server starting", japanese: "管理サーバーを起動中")
            message = l10n.text(english: "MLX Server Manager has started a managed launch for \(host):\(port). Readiness is still separate from process startup.", japanese: "MLX Server Managerが\(host):\(port)の管理起動を開始しました。Ready状態はプロセス起動とは別です。")
            processState = l10n.text(english: "Starting managed process", japanese: "管理プロセスを起動中")
            readiness = l10n.text(english: "Not checked - waiting for /v1/models", japanese: "未確認 - /v1/modelsを待機中")
            lifecycle = l10n.text(english: "Lifecycle controls apply to the managed launch", japanese: "ライフサイクル操作は管理起動に適用されます")
            lifecycleNote = l10n.text(english: "Running or starting does not necessarily mean ready; ready requires a successful /v1/models check.", japanese: "実行中または起動中はReadyを意味しません。Readyには/v1/models確認の成功が必要です。")
            accentColor = .orange
        case let .loading(host, port, processIdentifier):
            title = l10n.text(english: "Managed process loading", japanese: "管理プロセスをロード中")
            message = l10n.text(english: "App-owned process pid \(processIdentifier) is attached at \(host):\(port), but readiness has not completed.", japanese: "アプリ所有プロセス pid \(processIdentifier) が\(host):\(port)に接続されていますが、Ready確認は完了していません。")
            processState = l10n.text(english: "Managed pid \(processIdentifier)", japanese: "管理pid \(processIdentifier)")
            readiness = l10n.text(english: "Checking - waiting for /v1/models", japanese: "確認中 - /v1/modelsを待機中")
            lifecycle = l10n.text(english: "Stop and Restart apply to this managed process", japanese: "停止と再起動はこの管理プロセスに適用されます")
            lifecycleNote = l10n.text(english: "Readiness is distinct from process attachment.", japanese: "Ready状態はプロセス接続とは別です。")
            accentColor = .orange
        case let .ready(_, _, processIdentifier):
            title = l10n.text(english: "Server ready", japanese: "サーバーはReadyです")
            message = l10n.text(english: "The readiness check succeeded. OpenAI-compatible clients can use the current connection target.", japanese: "Ready確認に成功しました。OpenAI互換クライアントは現在の接続先を使用できます。")
            if let processIdentifier {
                processState = l10n.text(english: "Managed pid \(processIdentifier)", japanese: "管理pid \(processIdentifier)")
                lifecycle = l10n.text(english: "Stop and Restart apply to this managed process", japanese: "停止と再起動はこの管理プロセスに適用されます")
                lifecycleNote = l10n.text(english: "Ready means /v1/models responded successfully for the current endpoint.", japanese: "Readyは現在のエンドポイントで/v1/modelsが正常応答したことを意味します。")
            } else {
                processState = l10n.text(english: "Ready endpoint, no managed pid attached", japanese: "Readyエンドポイントですが、管理pidは付いていません")
                lifecycle = l10n.text(english: "No app-owned process is attached", japanese: "アプリ所有プロセスは付いていません")
                lifecycleNote = l10n.text(english: "Readiness can describe endpoint reachability without implying process ownership.", japanese: "Ready状態はプロセス所有を意味せず、エンドポイント到達性だけを示す場合があります。")
            }
            readiness = l10n.text(english: "Ready - /v1/models responded successfully", japanese: "Ready - /v1/modelsが正常応答")
            accentColor = .green
        case let .stopping(processIdentifier):
            title = l10n.text(english: "Managed server stopping", japanese: "管理サーバーを停止中")
            message = l10n.text(english: "MLX Server Manager is stopping app-owned process pid \(processIdentifier).", japanese: "MLX Server Managerがアプリ所有プロセス pid \(processIdentifier) を停止しています。")
            processState = l10n.text(english: "Stopping managed pid \(processIdentifier)", japanese: "管理pid \(processIdentifier) を停止中")
            readiness = l10n.text(english: "Unavailable - process is stopping", japanese: "利用不可 - プロセス停止中")
            lifecycle = l10n.text(english: "Stop applies only to the app-managed process", japanese: "停止はアプリ管理プロセスのみに適用されます")
            lifecycleNote = l10n.text(english: "External servers are not affected by this stop operation.", japanese: "この停止操作は外部サーバーに影響しません。")
            accentColor = .orange
        case let .checkingPort(host, port):
            title = l10n.text(english: "Checking selected port", japanese: "選択ポートを確認中")
            message = l10n.text(english: "The app is checking whether \(host):\(port) is available. This does not start or stop a server.", japanese: "アプリが\(host):\(port)を利用できるか確認しています。サーバーの起動や停止は行いません。")
            processState = l10n.text(english: "No managed process attached", japanese: "管理プロセスは付いていません")
            readiness = l10n.text(english: "Not checked - port check in progress", japanese: "未確認 - ポート確認中")
            lifecycle = l10n.text(english: "No lifecycle action is running", japanese: "ライフサイクル操作は実行中ではありません")
            lifecycleNote = l10n.text(english: "Port checks are informational and do not take ownership of external processes.", japanese: "ポート確認は情報表示のみで、外部プロセスの所有権は取得しません。")
            accentColor = .orange
        case let .portAvailable(host, port):
            title = l10n.text(english: "Port available", japanese: "ポート利用可能")
            message = l10n.text(english: "\(host):\(port) is available for an explicit managed Start.", japanese: "\(host):\(port) は明示的な管理起動に利用できます。")
            processState = l10n.text(english: "No managed process attached", japanese: "管理プロセスは付いていません")
            readiness = l10n.text(english: "Not checked - no active server target", japanese: "未確認 - 有効なサーバー接続先なし")
            lifecycle = l10n.text(english: "Start remains an explicit user action", japanese: "起動は明示的なユーザー操作のままです")
            lifecycleNote = l10n.text(english: "Availability does not automatically start mlx_lm.server.", japanese: "利用可能であってもmlx_lm.serverを自動起動しません。")
            accentColor = .green
        case let .portBusy(host, port):
            title = l10n.text(english: "Port busy", japanese: "ポート使用中")
            message = l10n.text(english: "\(host):\(port) is in use. MLX Server Manager will not launch a second server on this port.", japanese: "\(host):\(port) は使用中です。MLX Server Managerはこのポートで2つ目のサーバーを起動しません。")
            processState = l10n.text(english: "No managed process attached", japanese: "管理プロセスは付いていません")
            readiness = l10n.text(english: "Unavailable - port is busy", japanese: "利用不可 - ポート使用中")
            lifecycle = l10n.text(english: "Start is blocked until the selected port is safe", japanese: "選択ポートが安全になるまで起動はブロックされます")
            lifecycleNote = l10n.text(english: "The app does not stop unknown external processes.", japanese: "アプリは不明な外部プロセスを停止しません。")
            accentColor = .red
        case let .externalServerDetected(host, port, _, _):
            title = l10n.text(english: "External server detected", japanese: "外部サーバーを検出")
            message = l10n.text(english: "An external OpenAI-compatible endpoint responded at \(host):\(port). It is not app-managed.", japanese: "\(host):\(port) で外部OpenAI互換エンドポイントが応答しました。アプリ管理ではありません。")
            processState = l10n.text(english: "External process, not owned", japanese: "外部プロセス、所有なし")
            readiness = l10n.text(english: "Ready - /v1/models responded successfully", japanese: "Ready - /v1/modelsが正常応答")
            lifecycle = l10n.text(english: "Adopt stores connection context only", japanese: "採用は接続コンテキストのみを保存します")
            lifecycleNote = l10n.text(english: "Stop and Restart remain unavailable for this external process.", japanese: "この外部プロセスでは停止と再起動は利用できません。")
            accentColor = .orange
        case let .adoptedExternalServer(host, port, _, _):
            title = l10n.text(english: "Adopted external context", japanese: "採用済み外部コンテキスト")
            message = l10n.text(english: "\(host):\(port) is adopted as connection context. MLX Server Manager does not own that process.", japanese: "\(host):\(port) を接続コンテキストとして採用しています。MLX Server Managerはそのプロセスを所有しません。")
            processState = l10n.text(english: "External process, connection context only", japanese: "外部プロセス、接続コンテキストのみ")
            readiness = l10n.text(english: "Ready - /v1/models responded successfully", japanese: "Ready - /v1/modelsが正常応答")
            lifecycle = l10n.text(english: "Forget clears app-side context only", japanese: "解除はアプリ側コンテキストのみを消去します")
            lifecycleNote = l10n.text(english: "Forget External Server does not stop or restart the external server.", japanese: "外部サーバー解除は外部サーバーを停止・再起動しません。")
            accentColor = .orange
        case let .portCheckFailed(host, port, message):
            title = l10n.text(english: "Port check failed", japanese: "ポート確認に失敗")
            self.message = l10n.text(english: "The app could not check \(host):\(port): \(message)", japanese: "アプリは\(host):\(port)を確認できませんでした: \(message)")
            processState = l10n.text(english: "No managed process attached", japanese: "管理プロセスは付いていません")
            readiness = l10n.text(english: "Failed - endpoint check failed", japanese: "失敗 - エンドポイント確認失敗")
            lifecycle = l10n.text(english: "No lifecycle action is running", japanese: "ライフサイクル操作は実行中ではありません")
            lifecycleNote = l10n.text(english: "No automatic recovery is attempted.", japanese: "自動復旧は試行しません。")
            accentColor = .red
        case let .checkingReady(host, port):
            title = l10n.text(english: "Checking readiness", japanese: "Ready確認中")
            message = l10n.text(english: "The app is checking \(host):\(port) with /v1/models.", japanese: "アプリが/v1/modelsで\(host):\(port)を確認しています。")
            processState = l10n.text(english: "Process ownership unchanged", japanese: "プロセス所有権は未変更")
            readiness = l10n.text(english: "Checking - /v1/models request in progress", japanese: "確認中 - /v1/modelsリクエスト実行中")
            lifecycle = l10n.text(english: "Readiness check only", japanese: "Ready確認のみ")
            lifecycleNote = l10n.text(english: "Readiness checks do not send inference requests or change lifecycle state.", japanese: "Ready確認は推論リクエストを送信せず、ライフサイクル状態も変更しません。")
            accentColor = .orange
        case let .readyCheckFailed(host, port, message):
            title = l10n.text(english: "Readiness failed", japanese: "Ready確認に失敗")
            self.message = l10n.text(english: "/v1/models did not confirm readiness for \(host):\(port): \(message)", japanese: "/v1/modelsは\(host):\(port)のReady状態を確認できませんでした: \(message)")
            processState = l10n.text(english: "Process ownership unchanged", japanese: "プロセス所有権は未変更")
            readiness = l10n.text(english: "Failed - readiness check failed", japanese: "失敗 - Ready確認失敗")
            lifecycle = l10n.text(english: "No automatic restart or recovery", japanese: "自動再起動や自動復旧はありません")
            lifecycleNote = l10n.text(english: "Use existing controls after checking setup, logs, and endpoint state.", japanese: "設定、ログ、エンドポイント状態を確認してから既存の操作を使ってください。")
            accentColor = .red
        case let .error(message):
            title = l10n.text(english: "Server state error", japanese: "サーバー状態エラー")
            self.message = message
            processState = l10n.text(english: "Check logs", japanese: "ログを確認")
            readiness = l10n.text(english: "Unavailable - error state", japanese: "利用不可 - エラー状態")
            lifecycle = l10n.text(english: "No automatic recovery", japanese: "自動復旧なし")
            lifecycleNote = l10n.text(english: "Existing lifecycle buttons remain the only way to start, stop, or restart.", japanese: "起動、停止、再起動には既存のライフサイクルボタンのみを使います。")
            accentColor = .red
        case let .unknown(message):
            title = l10n.text(english: "Server state unknown", japanese: "サーバー状態不明")
            self.message = message
            processState = l10n.text(english: "Unknown", japanese: "不明")
            readiness = l10n.text(english: "Unavailable - check status and logs", japanese: "利用不可 - 状態とログを確認してください")
            lifecycle = l10n.text(english: "No automatic recovery", japanese: "自動復旧なし")
            lifecycleNote = l10n.text(english: "The app does not infer or take ownership of unknown processes.", japanese: "アプリは不明なプロセスを推定したり所有したりしません。")
            accentColor = .yellow
        }
    }
}

struct DashboardDiagnosticsGuidanceCard: View {
    let runtimeState: ModelRuntimeState
    let targetSummary: ConnectionTargetSummary

    var body: some View {
        DashboardStatusCard(
            title: "Diagnostics & Logs Guidance",
            systemImage: "stethoscope",
            accentColor: display.accentColor
        ) {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(display.title)
                        .font(.callout.weight(.semibold))

                    Text(display.message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Divider()

                HStack(alignment: .top, spacing: 12) {
                    DashboardKeyValueRow(label: "Next Step", value: display.nextStep)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    DashboardKeyValueRow(label: "Readiness", value: display.readiness)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack(alignment: .top, spacing: 12) {
                    DashboardKeyValueRow(label: "Logs", value: display.logs)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    DashboardKeyValueRow(label: "Automation", value: display.automation)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Label(display.safetyNote, systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var display: DashboardDiagnosticsGuidanceDisplay {
        DashboardDiagnosticsGuidanceDisplay(
            runtimeState: runtimeState,
            targetSummary: targetSummary
        )
    }
}

private struct DashboardDiagnosticsGuidanceDisplay {
    let title: String
    let message: String
    let nextStep: String
    let readiness: String
    let logs: String
    let automation: String
    let safetyNote: String
    let accentColor: Color

    init(runtimeState: ModelRuntimeState, targetSummary: ConnectionTargetSummary) {
        switch runtimeState {
        case .stopped:
            title = "No active server target"
            message = "Start a managed server or adopt a detected external server through the existing controls."
            nextStep = "Run Diagnostics or press Start after setup is complete."
            readiness = "Not checked until a server target exists."
            logs = "Only app action logs are available while stopped."
            automation = "No background diagnostics or automatic Start is running."
            safetyNote = "The app waits for explicit user actions before changing lifecycle state."
            accentColor = .secondary
        case .starting, .loading:
            title = "Managed server is starting"
            message = "The app-managed process is attached or launching, but readiness may still be pending."
            nextStep = "Watch managed logs and wait for Ready before using clients."
            readiness = "Ready requires /v1/models to respond successfully."
            logs = "Managed server logs are available in the Logs section."
            automation = "The app does not send inference requests while waiting."
            safetyNote = "Running does not always mean ready; readiness and process state are separate."
            accentColor = .orange
        case let .ready(_, _, processIdentifier):
            if processIdentifier != nil {
                title = "Managed server ready"
                message = "The managed endpoint passed readiness and can be used by OpenAI-compatible clients."
                nextStep = "Copy connection settings or continue monitoring logs."
                logs = "Managed server logs remain available in the Logs section."
            } else {
                title = "Endpoint ready"
                message = "The endpoint passed readiness, but no app-managed pid is attached."
                nextStep = "Use connection settings, and check the endpoint owner for process logs."
                logs = "Only app logs are available unless this app started the server."
            }
            readiness = "Ready means /v1/models responded successfully."
            automation = "No automatic restart or request routing is active."
            safetyNote = "Clients connect directly to the target endpoint in Direct Mode."
            accentColor = .green
        case .stopping:
            title = "Managed server is stopping"
            message = "The app is stopping only the app-managed process."
            nextStep = "Wait for stopped state, then inspect logs if shutdown fails."
            readiness = "Unavailable while the managed process is stopping."
            logs = "Managed server logs may show shutdown details."
            automation = "External processes are not affected by this stop operation."
            safetyNote = "Stop remains scoped to the app-managed process only."
            accentColor = .orange
        case let .checkingPort(host, port):
            title = "Checking port availability"
            message = "The app is checking whether \(host):\(port) is safe for a managed launch."
            nextStep = "Wait for the port check result."
            readiness = "Readiness is not checked during a port availability check."
            logs = "App logs show the port check result."
            automation = "Port checks do not start, stop, or adopt servers."
            safetyNote = "This check is informational and does not take ownership of processes."
            accentColor = .orange
        case .portAvailable:
            title = "Port is available"
            message = "The selected port is available for an explicit managed Start."
            nextStep = "Press Start when you want MLX Server Manager to launch the server."
            readiness = "Not checked until a server is running or an endpoint is checked."
            logs = "App logs will show the next lifecycle action."
            automation = "No server is started automatically."
            safetyNote = "Availability is not a lifecycle action."
            accentColor = .green
        case let .portBusy(host, port):
            title = "Port is busy"
            message = "\(host):\(port) is already in use by another process or service."
            nextStep = "Change port, check the external owner, or adopt it only if readiness confirms the intended endpoint."
            readiness = "Busy does not mean ready; use /v1/models readiness to confirm compatibility."
            logs = "External process logs are not available in this app."
            automation = "The app does not kill or take ownership of the busy process."
            safetyNote = "Port busy guidance is informational; remediation stays manual."
            accentColor = .red
        case .externalServerDetected:
            title = "External server detected"
            message = "A compatible endpoint responded, but MLX Server Manager does not own the process."
            nextStep = "Adopt only if you want to use this endpoint as connection context."
            readiness = "Detection is based on /v1/models responding successfully."
            logs = "Check external logs in the terminal or app that launched the server."
            automation = "Adopt is not automatic and does not change process ownership."
            safetyNote = "Stop and Restart remain unavailable for detected external servers."
            accentColor = .orange
        case .adoptedExternalServer:
            title = "External context adopted"
            message = "The endpoint is saved as connection context only."
            nextStep = "Use copied connection settings, or Forget External Server to clear app-side context."
            readiness = "The app can describe connection status, not external process ownership."
            logs = "External server logs must be checked outside MLX Server Manager."
            automation = "Forget removes context only; it does not stop the external server."
            safetyNote = "Adopted external servers are not monitored for memory or managed logs."
            accentColor = .orange
        case let .portCheckFailed(host, port, _):
            title = "Port check needs attention"
            message = "The app could not determine the state of \(host):\(port)."
            nextStep = "Verify host, port, local networking, and app logs."
            readiness = "Readiness was not confirmed."
            logs = "Check app logs for the port check failure message."
            automation = "No automatic recovery is attempted."
            safetyNote = "The app does not start or stop processes after a failed port check."
            accentColor = .red
        case let .checkingReady(host, port):
            title = "Checking readiness"
            message = "The app is checking \(host):\(port) with /v1/models."
            nextStep = "Wait for the readiness result before troubleshooting further."
            readiness = "/v1/models request is in progress."
            logs = Self.isExternalTarget(targetSummary)
                ? "External process logs are outside this app."
                : "Managed logs are available if the app started the process."
            automation = "Readiness checks do not send chat completions."
            safetyNote = "Readiness checks do not change lifecycle state."
            accentColor = .orange
        case let .readyCheckFailed(host, port, _):
            title = "Readiness failed"
            message = "/v1/models did not confirm readiness for \(host):\(port)."
            nextStep = "Verify host, port, server logs, and whether the target is still starting or OpenAI-compatible."
            readiness = "Failed - /v1/models did not succeed."
            logs = Self.isExternalTarget(targetSummary)
                ? "Check external logs where that server was launched."
                : "Check managed server logs and endpoint settings."
            automation = "The app does not automatically restart or terminate processes."
            safetyNote = "Readiness failure is diagnostic information, not an ownership change."
            accentColor = .red
        case .error:
            title = "Error state"
            message = "The app reported an error for the current server state."
            nextStep = "Check app logs, managed server logs if available, and current settings."
            readiness = "Unavailable until the error is resolved and readiness succeeds."
            logs = "Logs are the first place to inspect the failure detail."
            automation = "No automatic recovery is attempted."
            safetyNote = "Use explicit lifecycle controls after reviewing the failure."
            accentColor = .red
        case .unknown:
            title = "Unknown state"
            message = "The app cannot confidently describe the current server state."
            nextStep = "Check logs and rerun diagnostics or readiness checks as needed."
            readiness = "Unknown until a check succeeds or fails clearly."
            logs = "App logs may explain the unknown state."
            automation = "The app does not infer ownership of unknown processes."
            safetyNote = "Unknown state does not trigger automatic Start, Stop, or Restart."
            accentColor = .yellow
        }
    }

    private static func isExternalTarget(_ targetSummary: ConnectionTargetSummary) -> Bool {
        targetSummary.targetType.localizedCaseInsensitiveContains("external")
            || targetSummary.ownershipNote.localizedCaseInsensitiveContains("external")
    }
}

struct DashboardProfileImportExportCard: View {
    let selectedModel: ModelConfig?
    let targetSummary: ConnectionTargetSummary
    let exportSummaryText: String

    var body: some View {
        DashboardStatusCard(
            title: "Profiles & Import / Export",
            systemImage: "list.bullet.rectangle",
            accentColor: .blue
        ) {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(display.title)
                        .font(.callout.weight(.semibold))

                    Text(display.message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Divider()

                HStack(alignment: .top, spacing: 12) {
                    DashboardKeyValueRow(label: "Selected Profile", value: display.selectedProfile)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    DashboardKeyValueRow(label: "Profile Endpoint", value: display.profileEndpoint)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack(alignment: .top, spacing: 12) {
                    DashboardKeyValueRow(label: "Current Target", value: display.currentTarget)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    DashboardKeyValueRow(label: "Relationship", value: display.relationship)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack(alignment: .top, spacing: 12) {
                    DashboardKeyValueRow(label: "Export", value: display.exportSummary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    DashboardKeyValueRow(label: "Import", value: display.importSummary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Label(display.safetyNote, systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var display: DashboardProfileImportExportDisplay {
        DashboardProfileImportExportDisplay(
            selectedModel: selectedModel,
            targetSummary: targetSummary,
            exportSummaryText: exportSummaryText
        )
    }
}

private struct DashboardProfileImportExportDisplay {
    let title: String
    let message: String
    let selectedProfile: String
    let profileEndpoint: String
    let currentTarget: String
    let relationship: String
    let exportSummary: String
    let importSummary: String
    let safetyNote: String

    init(
        selectedModel: ModelConfig?,
        targetSummary: ConnectionTargetSummary,
        exportSummaryText: String
    ) {
        if let selectedModel {
            let displayName = selectedModel.displayName.isEmpty
                ? selectedModel.modelID
                : selectedModel.displayName
            let profileBaseURL = "http://\(selectedModel.host):\(selectedModel.serverPort)/v1"
            let advancedText = selectedModel.advancedLaunchOptions?.isEmpty == false
                ? "Advanced options set"
                : "Simple launch defaults"

            title = "Selected profile metadata"
            message = "Selected profile is saved launch/configuration metadata. Current target is the active managed or adopted endpoint."
            selectedProfile = "\(displayName) - \(selectedModel.modelID)"
            profileEndpoint = "\(selectedModel.host):\(selectedModel.serverPort) (\(advancedText))"
            currentTarget = "\(targetSummary.targetType) - \(targetSummary.baseURL)"
            relationship = Self.relationshipText(
                profileBaseURL: profileBaseURL,
                targetSummary: targetSummary
            )
        } else {
            title = "No selected profile"
            message = "Create or import a profile before starting a managed server."
            selectedProfile = "No profile selected"
            profileEndpoint = "Unavailable"
            currentTarget = "\(targetSummary.targetType) - \(targetSummary.baseURL)"
            relationship = "A profile can be selected even when no managed server is running."
        }

        exportSummary = "\(exportSummaryText) Metadata only: profile names, model IDs, endpoints, and launch options when present."
        importSummary = "Preview validates first. Import Selected writes selected valid metadata. Rename changes imported display name; Replace updates one unambiguous local profile."
        safetyNote = "Import / Export does not download models, delete model files, import secrets, start servers, stop servers, or change external process ownership."
    }

    private static func relationshipText(
        profileBaseURL: String,
        targetSummary: ConnectionTargetSummary
    ) -> String {
        if !targetSummary.isActiveTarget {
            return "No active target. Start uses the selected profile for managed launch."
        }

        if targetSummary.baseURL == profileBaseURL {
            return "Active endpoint matches the selected profile endpoint."
        }

        if targetSummary.targetType.localizedCaseInsensitiveContains("external") {
            return "Current target is external connection context; selected profile remains metadata."
        }

        return "Profile endpoint and active endpoint differ; check selected/running model state."
    }
}

struct DashboardStatusCard<Content: View>: View {
    let title: String
    let systemImage: String
    let accentColor: Color
    let content: Content

    init(
        title: String,
        systemImage: String,
        accentColor: Color,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.accentColor = accentColor
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .foregroundStyle(accentColor)
                    .frame(width: 18)

                Text(title)
                    .font(.subheadline.weight(.semibold))
            }

            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        }
    }
}

struct DashboardKeyValueRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.callout)
                .lineLimit(2)
                .truncationMode(.middle)
                .textSelection(.enabled)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(value)")
    }
}
