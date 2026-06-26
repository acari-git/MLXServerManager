import SwiftUI

struct ConnectionSettingsView: View {
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
        VStack(alignment: .leading, spacing: 14) {
            Text(t("OpenAI-Compatible Connection", "OpenAI互換接続"))
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Label(targetSummary.targetType, systemImage: targetIconName)
                        .font(.subheadline.weight(.semibold))

                    if !targetSummary.isActiveTarget {
                        Text(t("Preview", "プレビュー"))
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(nsColor: .quaternaryLabelColor).opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }

                Text(targetSummary.ownershipNote)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(targetSummary.directModeNote)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            DetailGrid(rows: [
                (t("Target Type", "接続先タイプ"), targetSummary.targetType),
                ("Base URL", baseURL),
                ("Model ID", modelID),
                ("API Key", apiKeyPlaceholder),
                (t("Readiness", "準備状態"), targetSummary.readinessSummary),
                (t("Ownership", "管理範囲"), targetSummary.ownershipNote)
            ])

            VStack(alignment: .leading, spacing: 10) {
                Text(t("Copy", "コピー"))
                    .font(.subheadline.weight(.semibold))

                HStack(spacing: 10) {
                    Button {
                        onCopyBaseURL()
                    } label: {
                        Label(t("Copy Base URL", "Base URLをコピー"), systemImage: "link")
                    }

                    Button {
                        onCopyModelID()
                    } label: {
                        Label(t("Copy Model ID", "Model IDをコピー"), systemImage: "doc.on.doc")
                    }

                    Button {
                        onCopyAPIKeyPlaceholder()
                    } label: {
                        Label(t("Copy API Key Placeholder", "API Keyプレースホルダーをコピー"), systemImage: "key")
                    }
                }

                HStack(spacing: 10) {
                    Button {
                        onCopyConfig()
                    } label: {
                        Label(t("Copy JSON Config", "JSON設定をコピー"), systemImage: "curlybraces")
                    }

                    Button {
                        onCopyHermesAgentConfig()
                    } label: {
                        Label(t("Copy Hermes Agent Config", "Hermes Agent設定をコピー"), systemImage: "person.crop.circle.badge.checkmark")
                    }

                    Button {
                        onCopyAllConnectionSettings()
                    } label: {
                        Label(t("Copy All Connection Settings", "接続設定をまとめてコピー"), systemImage: "doc.on.clipboard")
                    }
                }

                HStack(spacing: 10) {
                    Button {
                        onCopyModelsCurl()
                    } label: {
                        Label(t("Copy curl Readiness Check", "Ready確認curlをコピー"), systemImage: "terminal")
                    }

                    Button {
                        onCopyChatCompletionsCurl()
                    } label: {
                        Label(t("Copy OpenAI Chat Example", "OpenAIチャット例をコピー"), systemImage: "terminal")
                    }
                }

                Text(t(
                    "Chat examples are client-side helper text. MLX Server Manager does not run inference requests.",
                    "チャット例はクライアント側の補助テキストです。MLX Server Managerは推論リクエストを実行しません。"
                ))
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .panelStyle()
    }

    private var targetIconName: String {
        switch targetSummary.targetType {
        case "Managed Server":
            "server.rack"
        case "External Server Detected":
            "network"
        case "Adopted External Server":
            "link"
        default:
            "power"
        }
    }
}
