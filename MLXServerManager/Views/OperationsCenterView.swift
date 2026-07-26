import SwiftUI

private struct LaunchPlanEditorPresentation: Identifiable {
    let id = UUID()
    let plan: LaunchPlanDefinition?
}

struct OperationsCenterView: View {
    let state: OperationsCenterViewState
    let launchPlans: [LaunchPlanDefinition]
    let models: [ModelConfig]
    let language: AppLanguage
    let onRefresh: () -> Void
    let onCancel: () -> Void
    let onRefreshEvidence: () -> Void
    let onRunStability: () -> Void
    let onCancelStability: () -> Void
    let onRecordCalibration: () -> Void
    let onCreateSelectedPlan: () -> Void
    let onCreateAllPlan: () -> Void
    let onDeletePlan: (LaunchPlanDefinition) -> Void
    let onSavePlan: (LaunchPlanDefinition) -> Void
    let onSetPlanStepRequired: (LaunchPlanDefinition, String, Bool) -> Void
    let onMovePlanStep: (LaunchPlanDefinition, String, Int) -> Void
    let onRunPlan: (LaunchPlanDefinition) -> Void
    let onCancelPlan: () -> Void
    let onStopPlanStarted: () -> Void
    let onRefreshCapacity: (LaunchPlanDefinition) -> Void
    let onGenerateSupportBundle: () -> Void
    let onCopySupportBundle: () -> Void
    let onDismiss: () -> Void

    @State private var launchPlanEditorPresentation: LaunchPlanEditorPresentation?

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
                    if let message = state.message {
                        messageCard(message)
                    }
                    platformAndReadinessSection
                    evidenceSection
                    runtimeDoctorSection
                    modelMetadataSection
                    stabilityAndCalibrationSection
                    launchPlansSection
                    capacitySection
                    supportBundleSection
                }
                .padding(18)
            }
        }
        .frame(minWidth: 940, minHeight: 700)
        .accessibilityIdentifier("operations-center-view")
        .sheet(item: $launchPlanEditorPresentation) { presentation in
            LaunchPlanEditorView(
                models: models,
                existingPlan: presentation.plan,
                language: language,
                onSave: { plan in
                    onSavePlan(plan)
                    launchPlanEditorPresentation = nil
                },
                onCancel: {
                    launchPlanEditorPresentation = nil
                }
            )
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(t("Operations Center", "運用センター"))
                    .font(.title3.weight(.semibold))
                Text(t(
                    "Platform, environment, model, launch stability, calibration, launch plans, capacity, and support evidence in one explicit control surface.",
                    "プラットフォーム、環境、モデル、起動安定性、実測、起動プラン、容量、サポート情報を一つの明示操作画面で確認します。"
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
            .accessibilityIdentifier("operations-center-run-all")

            Button(t("Close", "閉じる"), action: onDismiss)
                .buttonStyle(.bordered)
        }
    }

    private var checkingCard: some View {
        HStack(spacing: 12) {
            ProgressView()
            Text(t(
                "Inspecting the configured environment without generation, installation, server start, or automatic settings changes…",
                "生成、インストール、サーバー起動、自動設定変更を行わず、設定済み環境を確認しています…"
            ))
            .font(.callout)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func messageCard(_ message: String) -> some View {
        Label(message, systemImage: "info.circle")
            .font(.callout)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.accentColor.opacity(0.08))
            )
    }

    private var platformAndReadinessSection: some View {
        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible())],
            alignment: .leading,
            spacing: 12
        ) {
            platformCard
            readinessCard
        }
        .accessibilityIdentifier("operations-center-platform-readiness")
    }

    private var platformCard: some View {
        GroupBox {
            if let platform = state.platform {
                HStack(alignment: .top, spacing: 12) {
                    statusIcon(platform.status)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(platform.status.localizedTitle(language: language))
                                .font(.callout.weight(.semibold))
                            Spacer()
                            Text(platform.architecture)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }
                        Text(platform.localizedDetail(language: language))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.vertical, 6)
            } else {
                emptyText(
                    english: "Run all checks to verify the OS and architecture baseline.",
                    japanese: "すべて確認を実行して、OSとアーキテクチャの基準を確認してください。"
                )
            }
        } label: {
            Label(t("Platform Compatibility", "プラットフォーム互換性"), systemImage: "macmini")
        }
    }

    private var readinessCard: some View {
        GroupBox {
            if let report = state.operationalReadiness {
                HStack(alignment: .top, spacing: 12) {
                    readinessIcon(report.overallStatus)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(report.overallStatus.localizedTitle(language: language))
                            .font(.callout.weight(.semibold))
                        Text(t(
                            "Blocking: \(report.blockingCount), review: \(report.attentionCount), profile: \(report.selectedProfileName ?? "Not selected").",
                            "起動不可: \(report.blockingCount)件、要確認: \(report.attentionCount)件、プロファイル: \(report.selectedProfileName ?? "未選択")。"
                        ))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 6)
            } else {
                emptyText(
                    english: "Select a profile and run all checks.",
                    japanese: "プロファイルを選択して、すべて確認を実行してください。"
                )
            }
        } label: {
            Label(t("Operational Readiness", "運用準備状態"), systemImage: "checklist")
        }
    }

    private var evidenceSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                if state.evidence.isEmpty {
                    emptyText(
                        english: "No comparison evidence has been captured.",
                        japanese: "比較用の確認情報はまだ取得されていません。"
                    )
                } else {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 190), spacing: 10)],
                        alignment: .leading,
                        spacing: 10
                    ) {
                        ForEach(state.evidence) { item in
                            VStack(alignment: .leading, spacing: 5) {
                                HStack(spacing: 7) {
                                    Image(systemName: freshnessSymbol(item.status))
                                        .foregroundStyle(freshnessColor(item.status))
                                    Text(item.domain.localizedTitle(language: language))
                                        .font(.caption.weight(.semibold))
                                    Spacer(minLength: 4)
                                    Text(item.status.localizedTitle(language: language))
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(freshnessColor(item.status))
                                }
                                Text(item.localizedDetail(language: language))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, minHeight: 88, alignment: .topLeading)
                            .background(cardBackground)
                        }
                    }
                }

                HStack {
                    Spacer()
                    Button {
                        onRefreshEvidence()
                    } label: {
                        Label(t("Compare Current Inputs", "現在の入力と比較"), systemImage: "arrow.triangle.2.circlepath")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .padding(.vertical, 6)
        } label: {
            Label(t("Evidence Freshness", "確認情報の鮮度"), systemImage: "clock.badge.checkmark")
        }
        .accessibilityIdentifier("operations-center-evidence")
    }

    private var runtimeDoctorSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                if state.runtimeReports.isEmpty {
                    emptyText(
                        english: "Run all checks to inspect configured runtime environments.",
                        japanese: "すべて確認を実行して、設定済みランタイム環境を診断してください。"
                    )
                } else {
                    ForEach(state.runtimeReports) { report in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                statusIcon(report.status)
                                Text(report.backend.localizedTitle(language: language))
                                    .font(.callout.weight(.semibold))
                                Spacer()
                                Text(report.version ?? t("Version unknown", "バージョン不明"))
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                            }

                            Text(compactPath(report.executablePath))
                                .font(.caption2.monospaced())
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                                .truncationMode(.middle)

                            ForEach(report.issues) { issue in
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: doctorSymbol(issue.severity))
                                        .foregroundStyle(doctorColor(issue.severity))
                                        .frame(width: 16)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(runtimeDoctorTitle(issue.kind))
                                            .font(.caption.weight(.semibold))
                                        Text(runtimeDoctorDetail(issue.kind))
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                            .fixedSize(horizontal: false, vertical: true)
                                        if let command = issue.commandPreview {
                                            Text(command)
                                                .font(.caption2.monospaced())
                                                .textSelection(.enabled)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(12)
                        .background(cardBackground)

                        if report.id != state.runtimeReports.last?.id {
                            Divider()
                        }
                    }
                }
            }
            .padding(.vertical, 6)
        } label: {
            Label(t("Runtime Environment Doctor", "ランタイム環境診断"), systemImage: "stethoscope")
        }
        .accessibilityIdentifier("operations-center-runtime-doctor")
    }

    private var modelMetadataSection: some View {
        GroupBox {
            if let report = state.modelMetadata {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        metadataStatusIcon(report.status)
                        Text(report.status.localizedTitle(language: language))
                            .font(.callout.weight(.semibold))
                        Spacer()
                        Text(report.modelID)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }

                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 170), spacing: 10)],
                        alignment: .leading,
                        spacing: 10
                    ) {
                        metadataValue(t("Model type", "モデル種別"), report.modelType ?? t("Unknown", "不明"))
                        metadataValue(t("Architecture", "アーキテクチャ"), report.architectures.isEmpty ? t("Unknown", "不明") : report.architectures.joined(separator: ", "))
                        metadataValue(t("Quantization", "量子化"), report.quantization ?? t("Unknown", "不明"))
                        metadataValue(t("Context length", "コンテキスト長"), report.contextLength.map(String.init) ?? t("Unknown", "不明"))
                        metadataValue(t("Vocabulary", "語彙数"), report.vocabularySize.map(String.init) ?? t("Unknown", "不明"))
                        metadataValue(t("Weight files", "重みファイル"), String(report.weightFileCount))
                        metadataValue(t("Shards", "シャード"), report.shardCount.map(String.init) ?? "—")
                        metadataValue(t("Chat template", "チャットテンプレート"), yesNo(report.hasChatTemplate))
                        metadataValue(t("Reasoning candidate", "推論候補"), yesNo(report.reasoningCandidate))
                        metadataValue(t("Tool calling candidate", "ツール呼び出し候補"), yesNo(report.toolCallingCandidate))
                    }

                    if !report.warnings.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(t("Review items", "確認事項"))
                                .font(.caption.weight(.semibold))
                            ForEach(Array(report.warnings.enumerated()), id: \.offset) { _, warning in
                                Label(metadataWarning(warning), systemImage: "exclamationmark.triangle")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding(.vertical, 6)
            } else {
                emptyText(
                    english: "Select a registered profile and run all checks to inspect local model metadata.",
                    japanese: "登録済みプロファイルを選択して、すべて確認を実行し、ローカルモデルのメタデータを解析してください。"
                )
            }
        } label: {
            Label(t("Model Metadata Inspector", "モデルメタデータ解析"), systemImage: "shippingbox.and.arrow.backward")
        }
        .accessibilityIdentifier("operations-center-model-metadata")
    }

    private var stabilityAndCalibrationSection: some View {
        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible())],
            alignment: .leading,
            spacing: 12
        ) {
            stabilityCard
            calibrationCard
        }
    }

    private var stabilityCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                if let report = state.stability {
                    HStack(spacing: 8) {
                        stabilityIcon(report.status)
                        Text(report.status.localizedTitle(language: language))
                            .font(.callout.weight(.semibold))
                        Spacer()
                        Text(t("\(report.samples.count) samples", "\(report.samples.count)回確認"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let last = report.samples.last {
                        Text(t(
                            "Latest ready: \(last.ready ? "Yes" : "No"), PID: \(last.processIdentifier.map(String.init) ?? "none"), memory: \(last.managedMemoryGigabytes.map { String(format: "%.1f GB", $0) } ?? "unknown").",
                            "最新Ready: \(last.ready ? "はい" : "いいえ")、PID: \(last.processIdentifier.map(String.init) ?? "なし")、メモリ: \(last.managedMemoryGigabytes.map { String(format: "%.1f GB", $0) } ?? "不明")。"
                        ))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                } else {
                    emptyText(
                        english: "Run an explicit short stability check for the selected app-managed server.",
                        japanese: "選択中のアプリ管理サーバーに対して、明示的な短時間安定性確認を実行します。"
                    )
                }

                HStack {
                    if state.stability?.status == .stabilizing {
                        Button(t("Cancel", "中止"), action: onCancelStability)
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                    Button {
                        onRunStability()
                    } label: {
                        Label(t("Check Stability", "安定性を確認"), systemImage: "waveform.path.ecg")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(state.stability?.status == .stabilizing)
                }
            }
            .padding(.vertical, 6)
        } label: {
            Label(t("Post-Launch Stability", "起動後の安定性"), systemImage: "heart.text.square")
        }
        .accessibilityIdentifier("operations-center-stability")
    }

    private var calibrationCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                if let latest = state.calibrationRecords.last {
                    Text(t("Latest local measurement", "最新のローカル実測"))
                        .font(.callout.weight(.semibold))
                    calibrationValue(
                        t("Observed memory", "実測メモリ"),
                        latest.observedManagedMemoryGigabytes.map { String(format: "%.1f GB", $0) } ?? t("Unknown", "不明")
                    )
                    calibrationValue(
                        t("Predicted memory", "予測メモリ"),
                        latest.predictedManagedMemoryGigabytes.map { String(format: "%.1f GB", $0) } ?? t("Unknown", "不明")
                    )
                    calibrationValue(
                        t("Benchmark speed", "ベンチマーク速度"),
                        latest.benchmarkTokensPerSecond.map { String(format: "%.1f tok/s", $0) } ?? t("Not measured", "未測定")
                    )
                } else {
                    emptyText(
                        english: "No resource calibration snapshot has been recorded.",
                        japanese: "リソース実測スナップショットはまだ記録されていません。"
                    )
                }

                Button {
                    onRecordCalibration()
                } label: {
                    Label(t("Record Current Measurement", "現在の実測を記録"), systemImage: "gauge.with.dots.needle.50percent")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.vertical, 6)
        } label: {
            Label(t("Resource Calibration", "リソース実測補正"), systemImage: "ruler")
        }
        .accessibilityIdentifier("operations-center-calibration")
    }

    private var launchPlansSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Button {
                        launchPlanEditorPresentation = LaunchPlanEditorPresentation(plan: nil)
                    } label: {
                        Label(t("New Custom Plan", "カスタムプランを作成"), systemImage: "square.and.pencil")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)

                    Button {
                        onCreateSelectedPlan()
                    } label: {
                        Label(t("Plan from Selected", "選択モデルから作成"), systemImage: "plus")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button {
                        onCreateAllPlan()
                    } label: {
                        Label(t("Plan from All Profiles", "全プロファイルから作成"), systemImage: "square.stack.3d.up")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Spacer()

                    if state.launchPlanExecution.phase == .starting
                        || state.launchPlanExecution.phase == .validating {
                        Button(t("Cancel Plan", "プランを中止"), action: onCancelPlan)
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                    if !state.launchPlanExecution.startedByPlanProfileIDs.isEmpty {
                        Button(t("Stop Plan-Started Servers", "プランで起動したサーバーを停止"), action: onStopPlanStarted)
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                }

                if launchPlans.isEmpty {
                    emptyText(
                        english: "No saved launch plans. Creating a plan never starts a server.",
                        japanese: "保存済み起動プランはありません。プラン作成だけでサーバーが起動することはありません。"
                    )
                } else {
                    ForEach(launchPlans) { plan in
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(plan.name)
                                    .font(.callout.weight(.semibold))
                                Text(t(
                                    "\(plan.steps.count) profile(s), \(plan.steps.filter(\.isRequired).count) required. Starts sequentially and preserves already-running profiles.",
                                    "\(plan.steps.count)プロファイル、必須\(plan.steps.filter(\.isRequired).count)件。順番に起動し、既に実行中のプロファイルは維持します。"
                                ))
                                .font(.caption)
                                .foregroundStyle(.secondary)

                                VStack(alignment: .leading, spacing: 5) {
                                    ForEach(Array(plan.steps.enumerated()), id: \.element.id) { index, step in
                                        HStack(spacing: 6) {
                                            Text("\(index + 1).")
                                                .font(.caption2.monospacedDigit())
                                                .foregroundStyle(.secondary)
                                                .frame(width: 20, alignment: .trailing)
                                            Text(modelName(for: step.profileID))
                                                .font(.caption)
                                                .lineLimit(1)
                                            Spacer(minLength: 8)
                                            Toggle(
                                                t("Required", "必須"),
                                                isOn: Binding(
                                                    get: { step.isRequired },
                                                    set: { onSetPlanStepRequired(plan, step.profileID, $0) }
                                                )
                                            )
                                            .toggleStyle(.checkbox)
                                            .font(.caption2)
                                            .fixedSize()
                                            Button {
                                                onMovePlanStep(plan, step.profileID, -1)
                                            } label: {
                                                Image(systemName: "chevron.up")
                                            }
                                            .buttonStyle(.borderless)
                                            .disabled(index == 0)
                                            .help(t("Move earlier", "前へ移動"))
                                            Button {
                                                onMovePlanStep(plan, step.profileID, 1)
                                            } label: {
                                                Image(systemName: "chevron.down")
                                            }
                                            .buttonStyle(.borderless)
                                            .disabled(index == plan.steps.count - 1)
                                            .help(t("Move later", "後へ移動"))
                                        }
                                    }
                                }
                                .padding(7)
                                .background(
                                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                                        .fill(Color(nsColor: .windowBackgroundColor).opacity(0.6))
                                )
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            Button(t("Edit", "編集")) {
                                launchPlanEditorPresentation = LaunchPlanEditorPresentation(plan: plan)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            Button(t("Capacity", "容量確認")) {
                                onRefreshCapacity(plan)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            Button(t("Run", "実行")) {
                                onRunPlan(plan)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            .disabled(state.launchPlanExecution.phase == .starting
                                || state.launchPlanExecution.phase == .validating)
                            Button(t("Delete", "削除"), role: .destructive) {
                                onDeletePlan(plan)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        .padding(10)
                        .background(cardBackground)
                    }
                }

                if state.launchPlanExecution.phase != .idle {
                    Divider()
                    HStack(spacing: 8) {
                        if state.launchPlanExecution.phase == .starting
                            || state.launchPlanExecution.phase == .validating
                            || state.launchPlanExecution.phase == .stopping {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text(launchPlanPhaseTitle(state.launchPlanExecution.phase))
                            .font(.caption.weight(.semibold))
                        if let message = state.launchPlanExecution.message {
                            Text(message)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(.vertical, 6)
        } label: {
            Label(t("Profile Groups and Launch Plans", "プロファイルグループと起動プラン"), systemImage: "list.number")
        }
        .accessibilityIdentifier("operations-center-launch-plans")
    }

    private var capacitySection: some View {
        GroupBox {
            if let capacity = state.capacity {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        capacityIcon(capacity.level)
                        Text(capacity.level.localizedTitle(language: language))
                            .font(.callout.weight(.semibold))
                        Spacer()
                        Text(t(
                            "\(capacity.items.count) profiles",
                            "\(capacity.items.count)プロファイル"
                        ))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    Text(capacityDetail(capacity))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if !capacity.recommendedOrder.isEmpty {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(t("Recommended start order", "推奨起動順序"))
                                .font(.caption.weight(.semibold))
                            ForEach(Array(capacity.recommendedOrder.enumerated()), id: \.element) { index, profileID in
                                HStack(spacing: 7) {
                                    Text("\(index + 1).")
                                        .font(.caption2.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                        .frame(width: 20, alignment: .trailing)
                                    Text(modelName(for: profileID))
                                        .font(.caption)
                                }
                            }
                            Text(t(
                                "This order starts smaller known estimates first. It is guidance only; the saved plan order is unchanged.",
                                "既知の推定容量が小さい順です。これは参考情報であり、保存済みプランの順序は変更しません。"
                            ))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        }
                        .padding(9)
                        .background(cardBackground)
                    }

                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 210), spacing: 8)],
                        alignment: .leading,
                        spacing: 8
                    ) {
                        ForEach(capacity.items) { item in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.displayName)
                                        .font(.caption.weight(.semibold))
                                    Text(item.isAlreadyRunning
                                        ? t("Already running", "実行中")
                                        : item.estimatedGigabytes.map { String(format: "%.1f GB", $0) }
                                            ?? t("Size unknown", "容量不明"))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            .padding(8)
                            .background(cardBackground)
                        }
                    }
                }
                .padding(.vertical, 6)
            } else {
                emptyText(
                    english: "Choose Capacity on a saved launch plan or run all checks.",
                    japanese: "保存済み起動プランの「容量確認」を選ぶか、すべて確認を実行してください。"
                )
            }
        } label: {
            Label(t("Capacity-Aware Multi-Model Operations", "容量を考慮した複数モデル運用"), systemImage: "memorychip")
        }
        .accessibilityIdentifier("operations-center-capacity")
    }

    private var supportBundleSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                Text(t(
                    "Creates a bounded memory-only troubleshooting summary. It excludes prompts, responses, model files, credentials, raw environment variables, and full home paths.",
                    "上限付きのメモリ内トラブルシューティング概要を作成します。プロンプト、応答、モデルファイル、資格情報、生の環境変数、ホーム配下のフルパスは含めません。"
                ))
                .font(.caption)
                .foregroundStyle(.secondary)

                if let bundle = state.supportBundle {
                    ScrollView(.vertical) {
                        Text(bundle.text)
                            .font(.caption2.monospaced())
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(minHeight: 120, maxHeight: 220)
                    .padding(10)
                    .background(cardBackground)
                }

                HStack {
                    Button {
                        onGenerateSupportBundle()
                    } label: {
                        Label(t("Generate", "生成"), systemImage: "doc.text.magnifyingglass")
                    }
                    .buttonStyle(.bordered)

                    Button {
                        onCopySupportBundle()
                    } label: {
                        Label(t("Copy Redacted Bundle", "マスキング済み内容をコピー"), systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(.vertical, 6)
        } label: {
            Label(t("Support Bundle", "サポート情報"), systemImage: "lifepreserver")
        }
        .accessibilityIdentifier("operations-center-support-bundle")
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 9, style: .continuous)
            .fill(Color(nsColor: .controlBackgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.55), lineWidth: 1)
            )
    }

    private func emptyText(english: String, japanese: String) -> some View {
        Text(t(english, japanese))
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 6)
    }

    private func metadataValue(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.medium))
                .lineLimit(2)
        }
        .padding(8)
        .frame(maxWidth: .infinity, minHeight: 52, alignment: .topLeading)
        .background(cardBackground)
    }

    private func calibrationValue(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption.monospacedDigit())
        }
    }

    private func yesNo(_ value: Bool) -> String {
        value ? t("Yes", "あり") : t("No", "なし")
    }

    private func compactPath(_ path: String) -> String {
        path.isEmpty ? t("Not configured", "未設定") : ModelAvailabilityPathFormatter.compact(path: path)
    }

    private func modelName(for profileID: String) -> String {
        models.first(where: { $0.id == profileID })?.displayName
            ?? t("Missing profile", "削除済みプロファイル")
    }

    private func statusIcon(_ status: OperationsCenterStatus) -> some View {
        Image(systemName: operationsStatusSymbol(status))
            .foregroundStyle(operationsStatusColor(status))
            .frame(width: 18)
    }

    private func operationsStatusSymbol(_ status: OperationsCenterStatus) -> String {
        switch status {
        case .ready: "checkmark.circle.fill"
        case .review: "exclamationmark.triangle.fill"
        case .blocking: "xmark.octagon.fill"
        case .unknown: "questionmark.circle"
        }
    }

    private func operationsStatusColor(_ status: OperationsCenterStatus) -> Color {
        switch status {
        case .ready: .green
        case .review: .orange
        case .blocking: .red
        case .unknown: .secondary
        }
    }

    private func readinessIcon(_ status: OperationalReadinessStatus) -> some View {
        Image(systemName: readinessSymbol(status))
            .foregroundStyle(readinessColor(status))
            .frame(width: 18)
    }

    private func readinessSymbol(_ status: OperationalReadinessStatus) -> String {
        switch status {
        case .ready: "checkmark.circle.fill"
        case .attention: "exclamationmark.triangle.fill"
        case .blocking: "xmark.octagon.fill"
        case .unknown: "questionmark.circle"
        case .checking: "hourglass"
        }
    }

    private func readinessColor(_ status: OperationalReadinessStatus) -> Color {
        switch status {
        case .ready: .green
        case .attention: .orange
        case .blocking: .red
        case .unknown: .secondary
        case .checking: .accentColor
        }
    }

    private func freshnessSymbol(_ status: EvidenceFreshnessStatus) -> String {
        switch status {
        case .current: "checkmark.circle.fill"
        case .stale: "clock.badge.exclamationmark"
        case .unavailable: "questionmark.circle"
        }
    }

    private func freshnessColor(_ status: EvidenceFreshnessStatus) -> Color {
        switch status {
        case .current: .green
        case .stale: .orange
        case .unavailable: .secondary
        }
    }

    private func doctorSymbol(_ severity: RuntimeDoctorSeverity) -> String {
        switch severity {
        case .info: "checkmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .blocking: "xmark.octagon.fill"
        }
    }

    private func doctorColor(_ severity: RuntimeDoctorSeverity) -> Color {
        switch severity {
        case .info: .green
        case .warning: .orange
        case .blocking: .red
        }
    }

    private func runtimeDoctorTitle(_ kind: RuntimeDoctorIssueKind) -> String {
        switch kind {
        case .pathNotConfigured: t("Runtime path is not configured", "ランタイムパスが未設定です")
        case .pathMissing: t("Runtime executable is missing", "ランタイム実行ファイルがありません")
        case .notExecutable: t("Runtime file is not executable", "実行権限がありません")
        case .unsupportedArchitecture: t("Unsupported runtime architecture", "未対応のランタイムアーキテクチャです")
        case .interpreterMissing: t("Script interpreter is missing", "スクリプトのインタープリターがありません")
        case .dependencyFailure: t("Runtime dependency import failed", "ランタイム依存関係の読み込みに失敗しました")
        case .helpUnavailable: t("Runtime help flags were not detected", "ランタイムのヘルプフラグを検出できませんでした")
        case .versionUnavailable: t("Runtime version was not reported", "ランタイムバージョンを取得できませんでした")
        case .duplicateCandidate: t("Multiple runtime candidates were detected", "複数のランタイム候補を検出しました")
        case .ready: t("Runtime environment is ready", "ランタイム環境は準備済みです")
        }
    }

    private func runtimeDoctorDetail(_ kind: RuntimeDoctorIssueKind) -> String {
        switch kind {
        case .pathNotConfigured:
            t("Choose an executable path in Settings before starting this backend.", "このバックエンドを起動する前に、設定で実行ファイルを選択してください。")
        case .pathMissing:
            t("The configured executable path does not exist.", "設定済みの実行ファイルパスが存在しません。")
        case .notExecutable:
            t("Review file permissions before using this runtime.", "このランタイムを使用する前にファイル権限を確認してください。")
        case .unsupportedArchitecture:
            t("Use an arm64 runtime build for Apple Silicon and MLX.", "Apple SiliconとMLX向けのarm64ランタイムを使用してください。")
        case .interpreterMissing:
            t("The executable references an interpreter that is not present.", "実行ファイルが参照しているインタープリターが存在しません。")
        case .dependencyFailure:
            t("The executable starts, but its Python environment cannot import a required module.", "実行ファイルは開始できますが、Python環境が必要なモジュールを読み込めません。")
        case .helpUnavailable:
            t("Option support remains Unknown until bounded help output can be parsed.", "上限付きのヘルプ出力を解析できるまで、オプション対応状況は不明のままです。")
        case .versionUnavailable:
            t("The executable did not return a usable version line.", "実行ファイルから利用可能なバージョン行が返されませんでした。")
        case .duplicateCandidate:
            t("Review each candidate before changing the configured path.", "設定パスを変更する前に各候補を確認してください。")
        case .ready:
            t("The executable exists, is executable, and responded to bounded inspection commands.", "実行ファイルが存在し、実行可能で、上限付きの確認コマンドに応答しました。")
        }
    }

    private func metadataStatusIcon(_ status: ModelMetadataStatus) -> some View {
        let symbol: String
        let color: Color
        switch status {
        case .compatibleCandidate:
            symbol = "checkmark.circle.fill"
            color = .green
        case .review:
            symbol = "exclamationmark.triangle.fill"
            color = .orange
        case .incomplete:
            symbol = "xmark.octagon.fill"
            color = .red
        case .externalIdentifier:
            symbol = "link.circle"
            color = .secondary
        case .unavailable:
            symbol = "questionmark.circle"
            color = .secondary
        }
        return Image(systemName: symbol).foregroundStyle(color)
    }

    private func metadataWarning(_ warning: String) -> String {
        if warning == "config.json could not be decoded." {
            return t("config.json could not be decoded.", "config.jsonを解析できませんでした。")
        }
        if warning == "Tokenizer data was not detected." {
            return t("Tokenizer data was not detected.", "Tokenizerデータを検出できませんでした。")
        }
        if warning == "Safetensors weights were not detected." {
            return t("Safetensors weights were not detected.", "Safetensors重みファイルを検出できませんでした。")
        }
        if warning.hasPrefix("The weight index references") {
            return t(warning, "重みインデックスが存在しないシャードファイルを参照しています。")
        }
        if warning == "The registered local model directory is missing." {
            return t(warning, "登録済みローカルモデルフォルダがありません。")
        }
        return warning
    }

    private func stabilityIcon(_ status: LaunchStabilityStatus) -> some View {
        let symbol: String
        let color: Color
        switch status {
        case .stable:
            symbol = "checkmark.circle.fill"
            color = .green
        case .stabilizing:
            symbol = "hourglass"
            color = .accentColor
        case .degraded, .unstable:
            symbol = "exclamationmark.triangle.fill"
            color = .orange
        case .exited:
            symbol = "xmark.circle.fill"
            color = .red
        case .notRunning:
            symbol = "pause.circle"
            color = .secondary
        }
        return Image(systemName: symbol).foregroundStyle(color)
    }

    private func capacityIcon(_ level: CapacityAssessmentLevel) -> some View {
        let symbol: String
        let color: Color
        switch level {
        case .safe:
            symbol = "checkmark.circle.fill"
            color = .green
        case .caution:
            symbol = "exclamationmark.triangle.fill"
            color = .orange
        case .critical:
            symbol = "xmark.octagon.fill"
            color = .red
        case .unavailable:
            symbol = "questionmark.circle"
            color = .secondary
        }
        return Image(systemName: symbol).foregroundStyle(color)
    }

    private func capacityDetail(_ capacity: CapacityPlanAssessment) -> String {
        let candidate = capacity.candidateGigabytes.map { String(format: "%.1f GB", $0) } ?? t("unknown", "不明")
        let projected = capacity.projectedManagedGigabytes.map { String(format: "%.1f GB", $0) } ?? t("unknown", "不明")
        let available = capacity.availableGigabytes.map { String(format: "%.1f GB", $0) } ?? t("unknown", "不明")
        return t(
            "Candidate estimate: \(candidate). Projected managed total: \(projected). Current available memory: \(available). This is a conservative preflight estimate, not a guarantee.",
            "起動候補の推定: \(candidate)。管理対象合計の予測: \(projected)。現在の空きメモリ: \(available)。これは保守的な起動前推定であり、保証ではありません。"
        )
    }

    private func launchPlanPhaseTitle(_ phase: LaunchPlanExecutionPhase) -> String {
        switch phase {
        case .idle: t("Idle", "待機中")
        case .validating: t("Validating launch plan", "起動プランを検証中")
        case .starting: t("Starting profiles sequentially", "プロファイルを順番に起動中")
        case .completed: t("Launch plan completed", "起動プラン完了")
        case .failed: t("Launch plan failed", "起動プラン失敗")
        case .cancelled: t("Launch plan cancelled", "起動プラン中止")
        case .stopping: t("Stopping plan-started servers", "プランで起動したサーバーを停止中")
        }
    }
}
