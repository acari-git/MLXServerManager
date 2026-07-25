import SwiftUI

struct OperationalReadinessView: View {
    let state: OperationalReadinessViewState
    let language: AppLanguage
    let onRefresh: () -> Void
    let onCancel: () -> Void
    let onCopy: () -> Void
    let onReviewUnsupportedOptions: () -> Void
    let onReviewResourceForecast: () -> Void
    let onReviewTuning: (BenchmarkProfileTuningRecommendation) -> Void
    let onDismiss: () -> Void

    private var strings: AppLocalization {
        AppLocalization(language: language)
    }

    private func t(_ english: String, _ japanese: String) -> String {
        strings.text(english: english, japanese: japanese)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(18)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if state.isChecking {
                        checkingCard
                    }
                    if let report = state.report {
                        summaryCard(report)
                        readinessGrid(report)
                        modelHealthSection(report)
                        tuningSection(report)
                        diagnosisSection(report)
                    } else if !state.isChecking {
                        Text(t(
                            "Run the non-generating readiness inspection to review the selected profile.",
                            "生成を行わない運用準備確認を実行し、選択プロファイルを確認してください。"
                        ))
                        .foregroundStyle(.secondary)
                    }
                }
                .padding(18)
            }
        }
        .frame(minWidth: 760, minHeight: 620)
        .accessibilityIdentifier("operational-readiness-view")
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(t("Operational Readiness", "運用準備状態"))
                    .font(.title3.weight(.semibold))
                Text(t(
                    "Runs explicit non-generating checks. It does not start a server, download a model, change settings, or stop an external process.",
                    "明示的な非生成チェックを実行します。サーバー起動、モデルダウンロード、設定変更、外部プロセス停止は行いません。"
                ))
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            if state.isChecking {
                Button(t("Cancel", "中止"), action: onCancel)
                    .buttonStyle(.bordered)
            }
            Button {
                onRefresh()
            } label: {
                Label(t("Run All Checks", "すべて確認"), systemImage: "checkmark.shield")
            }
            .buttonStyle(.borderedProminent)
            .disabled(state.isChecking)

            Button(t("Close", "閉じる"), action: onDismiss)
                .buttonStyle(.bordered)
        }
    }

    private var checkingCard: some View {
        HStack(spacing: 12) {
            ProgressView()
            Text(t(
                "Checking runtime, model files, endpoint, resources, and benchmark evidence…",
                "ランタイム、モデルファイル、接続先、リソース、ベンチマーク根拠を確認しています…"
            ))
            .font(.callout)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func summaryCard(_ report: OperationalReadinessReport) -> some View {
        GroupBox {
            HStack(alignment: .center, spacing: 14) {
                Image(systemName: statusSymbol(report.overallStatus))
                    .font(.title2)
                    .foregroundStyle(statusColor(report.overallStatus))

                VStack(alignment: .leading, spacing: 4) {
                    Text(report.overallStatus.localizedTitle(language: language))
                        .font(.headline)
                    Text(t(
                        "Blocking: \(report.blockingCount), needs review: \(report.attentionCount). Profile: \(report.selectedProfileName ?? "Not selected").",
                        "起動不可: \(report.blockingCount)件、要確認: \(report.attentionCount)件。プロファイル: \(report.selectedProfileName ?? "未選択")。"
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    onCopy()
                } label: {
                    Label(t("Copy Report", "レポートをコピー"), systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)
            }
            .padding(.vertical, 6)
        } label: {
            Text(t("Summary", "概要"))
        }
    }

    private func readinessGrid(_ report: OperationalReadinessReport) -> some View {
        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible())],
            alignment: .leading,
            spacing: 12
        ) {
            ForEach(report.items) { item in
                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 8) {
                        Image(systemName: statusSymbol(item.status))
                            .foregroundStyle(statusColor(item.status))
                        Text(item.kind.localizedTitle(language: language))
                            .font(.callout.weight(.semibold))
                        Spacer(minLength: 4)
                        Text(item.status.localizedTitle(language: language))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(statusColor(item.status))
                    }
                    Text(item.localizedDetail(language: language))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if item.kind == .compatibility,
                       report.compatibilityAssessment?.canClearUnsupportedOptions == true {
                        Button(t("Review Cleared Draft", "解除案を確認"), action: onReviewUnsupportedOptions)
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                    if item.kind == .resourceForecast,
                       report.resourceForecast?.recommendedTemplate != nil {
                        Button(t("Review Safe Draft", "安全設定案を確認"), action: onReviewResourceForecast)
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, minHeight: 118, alignment: .topLeading)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color(nsColor: .separatorColor).opacity(0.65), lineWidth: 1)
                )
            }
        }
    }

    private func modelHealthSection(_ report: OperationalReadinessReport) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(report.modelHealthReports) { health in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: healthSymbol(health.status))
                            .foregroundStyle(healthColor(health.status))
                            .frame(width: 18)
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text(health.displayName)
                                    .font(.callout.weight(.semibold))
                                Text(health.status.localizedTitle(language: language))
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(healthColor(health.status))
                            }
                            Text(health.localizedDetail(language: language))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if let path = health.localPath {
                                Text(ModelAvailabilityPathFormatter.compact(path: path))
                                    .font(.caption2.monospaced())
                                    .foregroundStyle(.tertiary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    if health.id != report.modelHealthReports.last?.id {
                        Divider()
                    }
                }
            }
            .padding(.vertical, 6)
        } label: {
            Text(t("Registered Model Health", "登録済みモデルの健全性"))
        }
    }

    @ViewBuilder
    private func tuningSection(_ report: OperationalReadinessReport) -> some View {
        if !report.tuningRecommendations.isEmpty {
            GroupBox {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(report.tuningRecommendations) { recommendation in
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(recommendation.useCase.localizedTitle(language: language))
                                    .font(.callout.weight(.semibold))
                                Text(recommendation.localizedReason(language: language))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 8)
                            Button {
                                onReviewTuning(recommendation)
                            } label: {
                                Text(t("Review Draft", "編集案を確認"))
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        if recommendation.id != report.tuningRecommendations.last?.id {
                            Divider()
                        }
                    }
                }
                .padding(.vertical, 6)
            } label: {
                Text(t("Benchmark-Guided Tuning", "ベンチマークに基づく調整"))
            }
        }
    }

    @ViewBuilder
    private func diagnosisSection(_ report: OperationalReadinessReport) -> some View {
        if let diagnosis = report.launchFailureDiagnosis {
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Label(
                        diagnosis.category.localizedTitle(language: language),
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.orange)
                    Text(diagnosis.category.localizedGuidance(language: language))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ForEach(Array(diagnosis.evidenceLines.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.caption2.monospaced())
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.vertical, 6)
            } label: {
                Text(t("Latest Structured Launch Diagnosis", "最新の構造化起動診断"))
            }
        }
    }

    private func statusSymbol(_ status: OperationalReadinessStatus) -> String {
        switch status {
        case .ready: "checkmark.circle.fill"
        case .attention: "exclamationmark.triangle.fill"
        case .blocking: "xmark.octagon.fill"
        case .unknown: "questionmark.circle"
        case .checking: "hourglass"
        }
    }

    private func statusColor(_ status: OperationalReadinessStatus) -> Color {
        switch status {
        case .ready: .green
        case .attention: .orange
        case .blocking: .red
        case .unknown: .secondary
        case .checking: .accentColor
        }
    }

    private func healthSymbol(_ status: RegisteredModelHealthStatus) -> String {
        switch status {
        case .ready: "checkmark.circle.fill"
        case .incomplete, .missing: "xmark.circle.fill"
        case .externalIdentifier: "link.circle"
        case .duplicatePath: "square.on.square"
        case .uninspectable: "questionmark.circle"
        }
    }

    private func healthColor(_ status: RegisteredModelHealthStatus) -> Color {
        switch status {
        case .ready, .externalIdentifier: .green
        case .duplicatePath, .uninspectable: .orange
        case .incomplete, .missing: .red
        }
    }
}
