import SwiftUI

struct ClientSetupSurfaceView: View {
    let targetSummary: ConnectionTargetSummary
    let baseURL: String
    let modelID: String
    let apiKeyPlaceholder: String
    let language: AppLanguage
    let onCopyBaseURL: () -> Void
    let onCopyModelID: () -> Void
    let onCopyAPIKeyPlaceholder: () -> Void
    let onCopyConfig: () -> Void
    let onCopyAllConnectionSettings: () -> Void
    let onCopyHermesAgentConfig: () -> Void
    let onCopyModelsCurl: () -> Void
    let onCopyChatCompletionsCurl: () -> Void

    init(
        targetSummary: ConnectionTargetSummary,
        baseURL: String,
        modelID: String,
        apiKeyPlaceholder: String,
        language: AppLanguage = .system,
        onCopyBaseURL: @escaping () -> Void,
        onCopyModelID: @escaping () -> Void,
        onCopyAPIKeyPlaceholder: @escaping () -> Void,
        onCopyConfig: @escaping () -> Void,
        onCopyAllConnectionSettings: @escaping () -> Void,
        onCopyHermesAgentConfig: @escaping () -> Void,
        onCopyModelsCurl: @escaping () -> Void,
        onCopyChatCompletionsCurl: @escaping () -> Void
    ) {
        self.targetSummary = targetSummary
        self.baseURL = baseURL
        self.modelID = modelID
        self.apiKeyPlaceholder = apiKeyPlaceholder
        self.language = language
        self.onCopyBaseURL = onCopyBaseURL
        self.onCopyModelID = onCopyModelID
        self.onCopyAPIKeyPlaceholder = onCopyAPIKeyPlaceholder
        self.onCopyConfig = onCopyConfig
        self.onCopyAllConnectionSettings = onCopyAllConnectionSettings
        self.onCopyHermesAgentConfig = onCopyHermesAgentConfig
        self.onCopyModelsCurl = onCopyModelsCurl
        self.onCopyChatCompletionsCurl = onCopyChatCompletionsCurl
    }

    private var strings: AppLocalization {
        AppLocalization(language: language)
    }

    private func t(_ english: String, _ japanese: String) -> String {
        strings.text(english: english, japanese: japanese)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                summaryCards
                directModeCard
                safetyCard
                copyScopeCard

                ConnectionSettingsView(
                    targetSummary: targetSummary,
                    baseURL: baseURL,
                    modelID: modelID,
                    apiKeyPlaceholder: apiKeyPlaceholder,
                    language: language,
                    onCopyBaseURL: onCopyBaseURL,
                    onCopyModelID: onCopyModelID,
                    onCopyAPIKeyPlaceholder: onCopyAPIKeyPlaceholder,
                    onCopyConfig: onCopyConfig,
                    onCopyAllConnectionSettings: onCopyAllConnectionSettings,
                    onCopyHermesAgentConfig: onCopyHermesAgentConfig,
                    onCopyModelsCurl: onCopyModelsCurl,
                    onCopyChatCompletionsCurl: onCopyChatCompletionsCurl
                )
                .accessibilityIdentifier("client-setup-connection-settings")
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .accessibilityIdentifier("client-setup-surface")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "link.badge.plus")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color.accentColor)

                Text(t("Client Setup", "クライアント設定"))
                    .font(.title2.weight(.semibold))
            }

            Text(t(
                "Copy-safe OpenAI-compatible setup values. Clients connect directly to the active endpoint.",
                "コピーして使えるOpenAI互換の設定値を表示します。クライアントは有効なエンドポイントへ直接接続します。"
            ))
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("client-setup-header")
    }

    private var summaryCards: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 170), spacing: 12)],
            alignment: .leading,
            spacing: 12
        ) {
            summaryCard(t("Target", "接続先"), value: targetSummary.targetType, identifier: "client-setup-summary-target")
            summaryCard("Base URL", value: baseURL, identifier: "client-setup-summary-base-url")
            summaryCard("Model ID", value: modelID, identifier: "client-setup-summary-model-id")
            summaryCard(t("Readiness", "準備状態"), value: targetSummary.readinessSummary, identifier: "client-setup-summary-readiness")
        }
        .accessibilityIdentifier("client-setup-summary")
    }

    private func summaryCard(_ title: String, value: String, identifier: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .lineLimit(1)
                .textSelection(.enabled)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.secondary.opacity(0.12))
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier)
    }

    private var directModeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Direct Mode", systemImage: "arrow.right.circle")
                .font(.headline)

            Text("OpenAI-compatible client -> mlx_lm.server or adopted external server -> MLX model")
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            Text(t(
                "MLX Server Manager displays setup values and copy actions. It does not sit between the client and server, proxy inference traffic, rewrite requests, inspect requests, or provide Chat UI.",
                "MLX Server Managerは設定値とコピー操作だけを表示します。クライアントとサーバーの間には入らず、推論通信のプロキシ、リクエスト書き換え、リクエスト検査、チャットUI提供は行いません。"
            ))
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.secondary.opacity(0.12))
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("client-setup-direct-mode")
    }

    private var copyScopeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(t("Copy Scope", "コピー範囲"), systemImage: "doc.on.doc")
                .font(.headline)

            DetailGrid(rows: [
                ("Base URL", t("Copies the active endpoint base URL.", "有効なエンドポイントのBase URLをコピーします。")),
                ("Model ID", t("Copies the selected model identifier for OpenAI-compatible clients.", "OpenAI互換クライアント向けに選択モデルのIDをコピーします。")),
                ("API key placeholder", t("Copies the documented placeholder only; no secret is created.", "ドキュメント用のプレースホルダーのみをコピーします。シークレットは作成しません。")),
                (t("Config examples", "設定例"), t("Copies text examples only; no files are generated or written.", "テキスト例だけをコピーします。ファイルの生成や書き込みは行いません。"))
            ])
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.secondary.opacity(0.12))
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("client-setup-copy-scope")
    }

    private var safetyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(t("Safety Boundary", "安全境界"), systemImage: "lock")
                .font(.headline)

            DetailGrid(rows: [
                (t("Secrets", "シークレット"), t("No API keys, tokens, or secrets are generated or stored.", "APIキー、トークン、シークレットは生成・保存しません。")),
                (t("Config files", "設定ファイル"), t("No client config files are generated or persisted.", "クライアント設定ファイルは生成・永続化しません。")),
                (t("Endpoint testing", "エンドポイント確認"), t("No new network behavior is added here.", "ここでは新しいネットワーク動作を追加しません。")),
                (t("Ownership", "管理範囲"), targetSummary.ownershipNote)
            ])
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.secondary.opacity(0.12))
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("client-setup-safety-boundary")
    }
}
