import SwiftUI

struct DetailInspectorSurfaceView: View {
    let selectedModel: ModelConfig?
    let runningModelText: String
    let restartRequired: Bool
    let targetSummary: ConnectionTargetSummary
    let modelAvailability: ModelAvailabilitySummary
    var language: AppLanguage = .system
    let onCheckModelAvailability: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                summaryCards

                if let selectedModel {
                    selectedProfileCard(selectedModel)
                    modelAvailabilityCard
                    connectionTargetCard
                    boundaryNote
                } else {
                    emptyState
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .accessibilityIdentifier("detail-inspector-surface")
    }

    private var l10n: AppLocalization {
        AppLocalization(language: language)
    }

    private var selectedProfileText: String {
        selectedModel?.displayName ?? l10n.text(english: "None", japanese: "なし")
    }

    private var targetStatusText: String {
        targetSummary.isActiveTarget ? l10n.text(english: "Active", japanese: "有効") : l10n.text(english: "Inactive", japanese: "無効")
    }

    private var restartRequiredText: String {
        restartRequired ? l10n.text(english: "Yes", japanese: "はい") : l10n.text(english: "No", japanese: "いいえ")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "sidebar.right")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color.accentColor)

                Text(l10n.text(english: "Inspector", japanese: "インスペクター"))
                    .font(.title2.weight(.semibold))
            }

            Text(l10n.text(english: "Read-only selected profile details. Runtime controls remain on Dashboard.", japanese: "選択プロファイルの詳細を読み取り専用で表示します。ランタイム操作はダッシュボードにあります。"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("detail-inspector-header")
    }

    private var summaryCards: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 160), spacing: 12)],
            alignment: .leading,
            spacing: 12
        ) {
            summaryCard(l10n.text(english: "Selected", japanese: "選択中"), value: selectedProfileText, identifier: "detail-inspector-summary-selected")
            summaryCard(l10n.text(english: "Target", japanese: "接続先"), value: targetStatusText, identifier: "detail-inspector-summary-target")
            summaryCard(l10n.text(english: "Running", japanese: "実行中"), value: runningModelText, identifier: "detail-inspector-summary-running")
            summaryCard(l10n.text(english: "Restart required", japanese: "再起動必要"), value: restartRequiredText, identifier: "detail-inspector-summary-restart-required")
        }
        .accessibilityIdentifier("detail-inspector-summary")
    }

    private func summaryCard(_ title: String, value: String, identifier: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .lineLimit(1)
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

    private func selectedProfileCard(_ model: ModelConfig) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.displayName)
                        .font(.title3.weight(.semibold))
                    Text(model.modelID)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }

                Spacer()

                if restartRequired {
                    Label(l10n.text(english: "Restart required", japanese: "再起動必要"), systemImage: "arrow.clockwise.circle")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                }
            }

            DetailGrid(rows: [
                ("Model ID", model.modelID),
                (l10n.text(english: "Display Name", japanese: "表示名"), model.displayName),
                (l10n.text(english: "Family", japanese: "ファミリー"), model.family),
                (l10n.text(english: "Quantization", japanese: "量子化"), model.quantization),
                (l10n.text(english: "Context", japanese: "コンテキスト"), model.contextWindow),
                (l10n.text(english: "Local Name", japanese: "ローカル名"), model.localName),
                (l10n.text(english: "Endpoint", japanese: "エンドポイント"), "\(model.host):\(model.serverPort)"),
                ("Thinking", model.enableThinking ? l10n.text(english: "Enabled", japanese: "有効") : l10n.text(english: "Disabled", japanese: "無効")),
                (l10n.text(english: "Running", japanese: "実行中"), runningModelText),
                (l10n.text(english: "Notes", japanese: "メモ"), model.notes)
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
        .accessibilityIdentifier("detail-inspector-selected-profile")
    }

    private var modelAvailabilityCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(l10n.text(english: "Model Availability", japanese: "モデルの利用可否"))
                    .font(.headline)

                Spacer()

                Text(modelAvailability.state.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(modelAvailability.state == .present ? Color.accentColor : Color.secondary)
            }

            DetailGrid(rows: [
                (l10n.text(english: "Status", japanese: "ステータス"), modelAvailability.state.title),
                (l10n.text(english: "Profile", japanese: "プロファイル"), modelAvailability.profileDisplayName),
                (l10n.text(english: "Target", japanese: "接続先"), modelAvailability.configuredTarget),
                (l10n.text(english: "Checked Path", japanese: "確認パス"), modelAvailability.checkedPathSummary),
                (l10n.text(english: "Scope", japanese: "範囲"), modelAvailability.scopeText),
                (l10n.text(english: "Next Step", japanese: "次の手順"), modelAvailability.nextStep)
            ])

            Button {
                onCheckModelAvailability()
            } label: {
                Label(l10n.text(english: "Check Model Availability", japanese: "モデルの利用可否を確認"), systemImage: "magnifyingglass")
            }
            .disabled(!modelAvailability.canCheck)
            .accessibilityIdentifier("detail-inspector-model-availability-check")

            Text(l10n.text(english: "Checks only the selected profile's configured local path. It does not scan, download, delete, or verify launch compatibility.", japanese: "選択プロファイルに設定されたローカルパスだけを確認します。スキャン、ダウンロード、削除、起動互換性の検証は行いません。"))
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
        .accessibilityIdentifier("detail-inspector-model-availability")
    }

    private var connectionTargetCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(l10n.text(english: "Connection Target", japanese: "接続先"))
                    .font(.headline)

                Spacer()

                Text(targetStatusText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(targetSummary.isActiveTarget ? Color.accentColor : Color.secondary)
            }

            DetailGrid(rows: [
                (l10n.text(english: "Target Type", japanese: "接続先タイプ"), targetSummary.targetType),
                ("Base URL", targetSummary.baseURL),
                ("Model ID", targetSummary.modelID),
                (l10n.text(english: "Readiness", japanese: "準備状態"), targetSummary.readinessSummary),
                (l10n.text(english: "Ownership", japanese: "管理範囲"), targetSummary.ownershipNote),
                ("Direct Mode", targetSummary.directModeNote)
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
        .accessibilityIdentifier("detail-inspector-connection-target")
    }

    private var boundaryNote: some View {
        Label(l10n.text(english: "Inspector is read-only for profile and runtime changes. Availability checks do not mutate profiles or start servers.", japanese: "インスペクターはプロファイルとランタイム変更について読み取り専用です。利用可否確認はプロファイルを変更せず、サーバーも起動しません。"), systemImage: "lock")
            .font(.caption)
            .foregroundStyle(.secondary)
            .accessibilityIdentifier("detail-inspector-boundary-note")
    }

    private var emptyState: some View {
        ContentUnavailableView(
            l10n.text(english: "No Selected Profile", japanese: "プロファイルが選択されていません"),
            systemImage: "sidebar.right",
            description: Text(l10n.text(english: "Select a profile from Dashboard or Profiles. The inspector does not change runtime lifecycle behavior.", japanese: "ダッシュボードまたはプロファイル画面でプロファイルを選択してください。インスペクターはランタイムのライフサイクル動作を変更しません。"))
        )
        .frame(maxWidth: .infinity, minHeight: 260)
        .accessibilityIdentifier("detail-inspector-empty-state")
    }
}
