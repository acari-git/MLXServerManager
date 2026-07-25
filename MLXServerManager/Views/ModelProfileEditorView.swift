import SwiftUI

struct ModelProfileEditorView: View {
    @Binding var draft: ModelProfileDraft
    @State private var advancedOptionsStatus: String?
    @State private var selectedProfileTemplate: ModelProfileTemplate = .balanced
    @State private var validationShakeTrigger = 0
    @State private var draftBeforeTuning: ModelProfileDraft?

    let title: String
    let saveButtonTitle: String
    let noticeMessage: String?
    let message: String?
    let runtimeFieldsLocked: Bool
    let kvCacheEnvironment: KVCacheEnvironment
    let language: AppLanguage
    var compatibilityAssessment: ProfileCompatibilityAssessment? = nil
    var resourceForecast: StartResourceForecast? = nil
    var benchmarkTuningRecommendation: BenchmarkProfileTuningRecommendation? = nil
    var portSuggestionMessage: String? = nil
    var onSuggestPort: (() -> Void)? = nil
    var onEndpointInputChanged: (() -> Void)? = nil
    let onSave: () -> Bool
    let onCancel: () -> Void
    let onCopyPreview: (String) -> Void

    private var strings: AppLocalization {
        AppLocalization(language: language)
    }

    private func t(_ english: String, _ japanese: String) -> String {
        strings.text(english: english, japanese: japanese)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)

            Divider()

            ScrollView {
                editorContent
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        HStack {
            Text(title)
                .font(.headline)

            Spacer()

            HStack(spacing: 10) {
                Button {
                    onCancel()
                } label: {
                    Label(t("Cancel", "キャンセル"), systemImage: "xmark")
                }

                Button {
                    guard !onSave() else { return }
                    withAnimation(.linear(duration: 0.32)) {
                        validationShakeTrigger += 1
                    }
                } label: {
                    Label(saveButtonTitle, systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var editorContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let noticeMessage, !noticeMessage.isEmpty {
                Label(noticeMessage, systemImage: "info.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            if runtimeFieldsLocked {
                Label(
                    t("Stop the managed server before changing model path, backend, host, port, or advanced launch options.", "モデルパス、バックエンド、ホスト、ポート、詳細起動オプションを変更する前に、管理中のサーバーを停止してください。"),
                    systemImage: "lock.fill"
                )
                .font(.callout)
                .foregroundStyle(.secondary)
            }

            if let message, !message.isEmpty {
                Label(message, systemImage: "exclamationmark.triangle")
                    .font(.callout)
                    .foregroundStyle(.red)
            }

            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 16, verticalSpacing: 14) {
                editorRow(t("Display Name", "表示名")) {
                    TextField(t("Uses model path if empty", "空欄の場合はモデルパスを使用"), text: $draft.displayName)
                        .textFieldStyle(.roundedBorder)
                }

                editorRow(t("Model Path", "モデルパス")) {
                    TextField(t("Local path or Hugging Face model ID", "ローカルパスまたはHugging FaceモデルID"), text: $draft.modelID)
                        .textFieldStyle(.roundedBorder)
                        .kineticValidationFeedback(
                            isInvalid: validationTarget == .modelID,
                            trigger: validationShakeTrigger
                        )
                        .disabled(runtimeFieldsLocked)
                }

                editorRow(t("Backend", "バックエンド")) {
                    VStack(alignment: .leading, spacing: 4) {
                        Picker(t("Backend", "バックエンド"), selection: $draft.backend) {
                            ForEach(InferenceBackend.allCases) { backend in
                                Text(backend.localizedTitle(language: language))
                                    .tag(backend)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .disabled(runtimeFieldsLocked)

                        Text(draft.backend.localizedDetail(language: language))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                editorRow("Host") {
                    TextField("127.0.0.1", text: $draft.host)
                        .textFieldStyle(.roundedBorder)
                        .kineticValidationFeedback(
                            isInvalid: validationTarget == .host,
                            trigger: validationShakeTrigger
                        )
                        .disabled(runtimeFieldsLocked)
                        .onChange(of: draft.host) { _, _ in
                            onEndpointInputChanged?()
                        }
                }

                editorRow("Port") {
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 8) {
                            TextField("8080", text: $draft.serverPortText)
                                .textFieldStyle(.roundedBorder)
                                .kineticValidationFeedback(
                                    isInvalid: validationTarget == .port,
                                    trigger: validationShakeTrigger
                                )
                                .disabled(runtimeFieldsLocked)
                                .onChange(of: draft.serverPortText) { _, _ in
                                    onEndpointInputChanged?()
                                }

                            if let onSuggestPort {
                                Button(action: onSuggestPort) {
                                    Label(t("Find Available Port", "空きポートを検索"), systemImage: "network")
                                }
                                .disabled(runtimeFieldsLocked)
                            }
                        }

                        if let portSuggestionMessage, !portSuggestionMessage.isEmpty {
                            Text(portSuggestionMessage)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                editorRow(t("Reasoning Mode", "推論モード")) {
                    VStack(alignment: .leading, spacing: 4) {
                        Toggle(t("Enable reasoning mode", "推論モードを有効にする"), isOn: $draft.enableThinking)
                            .toggleStyle(.checkbox)
                        Text(t("For complex tasks. Responses may be slower.", "複雑なタスク向け。応答は遅くなる場合があります。"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                editorRow(t("Notes", "メモ")) {
                    borderedTextEditor(text: $draft.notes, minHeight: 112)
                }
            }

            profileTemplateSection

            compatibilitySection

            resourceForecastSection

            benchmarkTuningSection

            KineticDisclosureSection(
                label: {
                    Text(t("Advanced Launch Options", "詳細起動オプション"))
                        .font(.callout.weight(.medium))
                },
                content: {
                VStack(alignment: .leading, spacing: 12) {
                    Text(advancedDefaultsDescription)
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    Text(t("Advanced options are workload-dependent and may not improve performance.", "詳細オプションの効果はワークロードに依存し、性能改善を保証するものではありません。"))
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    kvCacheDiagnostic

                    Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 16, verticalSpacing: 14) {
                        advancedRow("Temperature") {
                            TextField("0.0 - 1.0", text: advancedBinding(\.defaultTemperature))
                                .textFieldStyle(.roundedBorder)
                        }

                        advancedRow("Top P") {
                            TextField("0.0 - 1.0", text: advancedBinding(\.defaultTopP))
                                .textFieldStyle(.roundedBorder)
                        }

                        advancedRow("Top K") {
                            TextField(t("Positive integer", "正の整数"), text: advancedBinding(\.defaultTopK))
                                .textFieldStyle(.roundedBorder)
                        }

                        advancedRow("Min P") {
                            TextField("0.0 - 1.0", text: advancedBinding(\.defaultMinP))
                                .textFieldStyle(.roundedBorder)
                        }

                        advancedRow("Max Tokens") {
                            TextField(t("Positive integer", "正の整数"), text: advancedBinding(\.defaultMaxTokens))
                                .textFieldStyle(.roundedBorder)
                        }

                        advancedRow("Allowed Origins") {
                            TextField(t("Optional origin list", "任意のオリジン一覧"), text: advancedBinding(\.allowedOrigins))
                                .textFieldStyle(.roundedBorder)
                        }

                        advancedRow("Log Level") {
                            TextField(t("Optional log level", "任意のログレベル"), text: advancedBinding(\.logLevel))
                                .textFieldStyle(.roundedBorder)
                        }

                        advancedRow("Decode Concurrency") {
                            TextField(t("Positive integer", "正の整数"), text: advancedBinding(\.decodeConcurrency))
                                .textFieldStyle(.roundedBorder)
                        }

                        advancedRow("Prompt Concurrency") {
                            TextField(t("Positive integer", "正の整数"), text: advancedBinding(\.promptConcurrency))
                                .textFieldStyle(.roundedBorder)
                        }

                        advancedRow("Prefill Step Size") {
                            TextField(t("Positive integer", "正の整数"), text: advancedBinding(\.prefillStepSize))
                                .textFieldStyle(.roundedBorder)
                        }

                        advancedRow("Prompt Cache Size") {
                            TextField(t("Positive integer", "正の整数"), text: advancedBinding(\.promptCacheSize))
                                .textFieldStyle(.roundedBorder)
                        }

                        advancedRow("Prompt Cache Bytes") {
                            TextField(t("Positive integer", "正の整数"), text: advancedBinding(\.promptCacheBytes))
                                .textFieldStyle(.roundedBorder)
                        }

                        if draft.backend == .mlxLM {
                            advancedRow("Chat Template Args") {
                                borderedTextEditor(
                                    text: advancedBinding(\.chatTemplateArgs),
                                    minHeight: 112,
                                    font: .system(.callout, design: .monospaced)
                                )
                            }
                        }

                        advancedRow("Raw Extra Args") {
                            VStack(alignment: .leading, spacing: 6) {
                                borderedTextEditor(
                                    text: advancedBinding(\.rawExtraArgs),
                                    minHeight: 112,
                                    font: .system(.callout, design: .monospaced)
                                )

                                Text(t("Expert only. Raw arguments are appended last and used only when explicitly set.", "上級者向けです。Raw引数は最後に追加され、明示した場合のみ使われます。"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(t("Launch Command Preview", "起動コマンドプレビュー"))
                                .font(.callout.weight(.medium))

                            Spacer()

                            KineticCopyButton(
                                feedbackTitle: t("Copied", "コピー済み"),
                                action: {
                                    onCopyPreview(launchCommandPreview)
                                    advancedOptionsStatus = t("Preview copied.", "プレビューをコピーしました。")
                                }
                            ) {
                                Label(t("Copy Preview", "プレビューをコピー"), systemImage: "doc.on.doc")
                            }
                            .disabled(!canCopyLaunchCommandPreview)

                            Button {
                                draft.advancedLaunchOptions = .empty
                                advancedOptionsStatus = t("Advanced options cleared.", "詳細オプションをクリアしました。")
                            } label: {
                                Label(t("Clear Advanced Options", "詳細オプションをクリア"), systemImage: "clear")
                            }
                        }

                        Text(launchCommandPreview)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if let advancedOptionsStatus {
                            Text(advancedOptionsStatus)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.top, 8)
                }
            )
            .kineticValidationFeedback(
                isInvalid: validationTarget == .advanced,
                trigger: validationShakeTrigger
            )
            .disabled(runtimeFieldsLocked)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var compatibilitySection: some View {
        if let assessment = compatibilityAssessment {
            GroupBox {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: compatibilitySymbol(assessment.level))
                            .foregroundStyle(compatibilityColor(assessment.level))
                        Text(assessment.level.localizedTitle(language: language))
                            .font(.callout.weight(.semibold))
                    }
                    Text(assessment.localizedDetail(language: language))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if !assessment.requestedFlags.isEmpty {
                        Text(assessment.requestedFlags.joined(separator: "  "))
                            .font(.caption2.monospaced())
                            .foregroundStyle(.tertiary)
                            .textSelection(.enabled)
                    }

                    if assessment.canClearUnsupportedOptions {
                        Button {
                            draft = RuntimeProfileCompatibilityAdvisor.clearingUnsupportedOptions(
                                in: draft,
                                flags: assessment.unsupportedFlags
                            )
                            advancedOptionsStatus = t(
                                "Unsupported options were removed from this unsaved draft.",
                                "未対応オプションを未保存の編集案から解除しました。"
                            )
                        } label: {
                            Label(t("Clear Unsupported Options", "未対応オプションを解除"), systemImage: "eraser")
                        }
                        .buttonStyle(.bordered)
                        .disabled(runtimeFieldsLocked)
                    }
                }
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
            } label: {
                Text(t("Runtime Compatibility", "ランタイム互換性"))
            }
            .accessibilityIdentifier("profile-runtime-compatibility")
        }
    }

    @ViewBuilder
    private var resourceForecastSection: some View {
        if let forecast = resourceForecast {
            GroupBox {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: resourceSymbol(forecast.assessment.level))
                            .foregroundStyle(resourceColor(forecast.assessment.level))
                        Text(forecast.localizedTitle(language: language))
                            .font(.callout.weight(.semibold))
                    }
                    Text(forecast.localizedDetail(language: language))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if forecast.didAdjustOptions || forecast.recommendedTemplate != nil {
                        Button {
                            draftBeforeTuning = draft
                            draft.advancedLaunchOptions = forecast.suggestedOptions
                            if let template = forecast.recommendedTemplate {
                                draft = template.applying(to: draft)
                            }
                            advancedOptionsStatus = t(
                                "Resource-safe values were applied to this unsaved draft.",
                                "リソース安全性を考慮した値を未保存の編集案へ反映しました。"
                            )
                        } label: {
                            Label(t("Apply Safe Draft", "安全設定案を反映"), systemImage: "shield.lefthalf.filled")
                        }
                        .buttonStyle(.bordered)
                        .disabled(runtimeFieldsLocked)
                    }
                }
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
            } label: {
                Text(t("Start Resource Forecast", "起動リソース予測"))
            }
            .accessibilityIdentifier("profile-resource-forecast")
        }
    }

    @ViewBuilder
    private var benchmarkTuningSection: some View {
        if let recommendation = benchmarkTuningRecommendation {
            GroupBox {
                VStack(alignment: .leading, spacing: 10) {
                    Text(recommendation.useCase.localizedTitle(language: language))
                        .font(.callout.weight(.semibold))
                    Text(recommendation.localizedReason(language: language))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 10) {
                        Button {
                            draftBeforeTuning = draft
                            draft = recommendation.template.applying(to: draft)
                            advancedOptionsStatus = t(
                                "Benchmark-guided template applied to this unsaved draft.",
                                "ベンチマークに基づくテンプレートを未保存の編集案へ反映しました。"
                            )
                        } label: {
                            Label(t("Apply Recommendation", "推奨設定を反映"), systemImage: "chart.bar.xaxis")
                        }
                        .buttonStyle(.bordered)
                        .disabled(runtimeFieldsLocked)

                        if let previous = draftBeforeTuning {
                            Button {
                                draft = previous
                                draftBeforeTuning = nil
                                advancedOptionsStatus = t("Draft change undone.", "編集案の変更を元に戻しました。")
                            } label: {
                                Label(t("Undo", "元に戻す"), systemImage: "arrow.uturn.backward")
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
            } label: {
                Text(t("Benchmark-Guided Tuning", "ベンチマークに基づく調整"))
            }
            .accessibilityIdentifier("profile-benchmark-tuning")
        }
    }

    private func compatibilitySymbol(_ level: ProfileCompatibilityLevel) -> String {
        switch level {
        case .compatible: "checkmark.circle.fill"
        case .blocked: "xmark.octagon.fill"
        case .unknown: "questionmark.circle"
        }
    }

    private func compatibilityColor(_ level: ProfileCompatibilityLevel) -> Color {
        switch level {
        case .compatible: .green
        case .blocked: .red
        case .unknown: .secondary
        }
    }

    private func resourceSymbol(_ level: MultiModelMemoryRiskLevel) -> String {
        switch level {
        case .safe: "checkmark.circle.fill"
        case .caution: "exclamationmark.triangle.fill"
        case .critical: "xmark.octagon.fill"
        case .unavailable: "questionmark.circle"
        }
    }

    private func resourceColor(_ level: MultiModelMemoryRiskLevel) -> Color {
        switch level {
        case .safe: .green
        case .caution: .orange
        case .critical: .red
        case .unavailable: .secondary
        }
    }

    private var profileTemplateSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 12) {
                    Picker(t("Template", "テンプレート"), selection: $selectedProfileTemplate) {
                        ForEach(ModelProfileTemplate.allCases) { template in
                            Text(template.localizedTitle(language: language))
                                .tag(template)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 190, alignment: .leading)

                    Button {
                        draft = selectedProfileTemplate.applying(to: draft)
                        advancedOptionsStatus = t(
                            "Applied \(selectedProfileTemplate.localizedTitle(language: .english)) template.",
                            "\(selectedProfileTemplate.localizedTitle(language: .japanese))テンプレートを適用しました。"
                        )
                    } label: {
                        Label(t("Apply Template", "テンプレートを適用"), systemImage: "wand.and.stars")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(runtimeFieldsLocked)

                    Spacer(minLength: 0)
                }

                Text(selectedProfileTemplate.localizedDetail(language: language))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(selectedProfileTemplate.localizedSettingsSummary(
                    backend: draft.backend,
                    language: language
                ))
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)

                Label(
                    t(
                        "Templates change only managed performance fields. Model identity, endpoint, notes, sampling, CORS, chat-template, and raw arguments are preserved.",
                        "テンプレートが変更するのは管理対象の性能項目だけです。モデル情報、接続先、メモ、サンプリング、CORS、チャットテンプレート、Raw引数は保持されます。"
                    ),
                    systemImage: "lock.shield"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(t("Profile Template", "プロファイルテンプレート"))
                    .font(.headline)
                Text(t(
                    "Apply a deterministic starting point before reviewing Advanced Launch Options.",
                    "詳細起動オプションを確認する前に、決定的な初期値を適用します。"
                ))
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .groupBoxStyle(.automatic)
        .accessibilityIdentifier("profile-template-section")
    }

    private var kvCacheAssessment: KVCacheAssessment {
        KVCacheAdvisor.assess(
            options: draft.advancedLaunchOptions,
            environment: kvCacheEnvironment,
            backend: draft.backend
        )
    }

    private var kvCacheSafeModeResult: KVCacheSafeModeResult {
        KVCacheSafeMode.apply(
            options: draft.advancedLaunchOptions,
            environment: kvCacheEnvironment,
            backend: draft.backend
        )
    }

    private var advancedDefaultsDescription: String {
        switch draft.backend {
        case .mlxLM:
            t("Leave empty to use mlx_lm.server defaults.", "空欄の場合はmlx_lm.serverの既定値を使用します。")
        case .rapidMLX:
            t("Leave empty to use Rapid-MLX defaults.", "空欄の場合はRapid-MLXの既定値を使用します。")
        }
    }

    private var kvCacheDiagnostic: some View {
        let assessment = kvCacheAssessment
        return GroupBox(t("KV Cache", "KVキャッシュ")) {
            VStack(alignment: .leading, spacing: 10) {
                Label(assessment.title(language: language), systemImage: kvCacheStatusSymbol(assessment.level))
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(kvCacheStatusColor(assessment.level))

                Text(assessment.detail(language: language))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(assessment.recommendationText(language: language))
                    .font(.caption)
                    .fixedSize(horizontal: false, vertical: true)

                if kvCacheSafeModeResult.didAdjust {
                    Label(
                        t("Runtime safe mode", "実行時安全モード"),
                        systemImage: "shield.lefthalf.filled"
                    )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                    Text(kvCacheSafeModeResult.actionText(language: language))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 10) {
                    Button {
                        let recommendation = assessment.recommendation
                        draft.advancedLaunchOptions.promptCacheSize = String(recommendation.entryLimit)
                        draft.advancedLaunchOptions.promptCacheBytes = String(recommendation.byteLimit)
                        advancedOptionsStatus = t("KV cache recommendation applied.", "KVキャッシュの推奨値を反映しました。")
                    } label: {
                        Label(t("Apply Recommendation", "推奨値を反映"), systemImage: "wand.and.stars")
                    }
                    .disabled(runtimeFieldsLocked)

                    Button {
                        draft.advancedLaunchOptions.promptCacheSize = nil
                        draft.advancedLaunchOptions.promptCacheBytes = nil
                        advancedOptionsStatus = t("KV cache settings reset to server defaults.", "KVキャッシュ設定をサーバー既定値へ戻しました。")
                    } label: {
                        Label(t("Use Server Defaults", "サーバー既定値を使用"), systemImage: "arrow.counterclockwise")
                    }
                    .disabled(runtimeFieldsLocked)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
        }
    }

    private func kvCacheStatusSymbol(_ level: KVCacheDiagnosisLevel) -> String {
        switch level {
        case .healthy:
            "checkmark.circle.fill"
        case .attention:
            "info.circle.fill"
        case .warning:
            "exclamationmark.triangle.fill"
        }
    }

    private func kvCacheStatusColor(_ level: KVCacheDiagnosisLevel) -> Color {
        switch level {
        case .healthy:
            .green
        case .attention:
            .orange
        case .warning:
            .red
        }
    }

    private func editorRow<Content: View>(
        _ label: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        GridRow {
            Text(label)
                .font(.callout.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(width: 120, alignment: .leading)

            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func advancedRow<Content: View>(
        _ label: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        GridRow {
            Text(label)
                .font(.callout.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(width: 150, alignment: .leading)

            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func advancedBinding(_ keyPath: WritableKeyPath<AdvancedLaunchOptions, String?>) -> Binding<String> {
        Binding {
            draft.advancedLaunchOptions[keyPath: keyPath] ?? ""
        } set: { newValue in
            draft.advancedLaunchOptions[keyPath: keyPath] = newValue
        }
    }

    private func borderedTextEditor(
        text: Binding<String>,
        minHeight: CGFloat,
        font: Font = .callout
    ) -> some View {
        TextEditor(text: text)
            .font(font)
            .scrollContentBackground(.hidden)
            .padding(6)
            .frame(minHeight: minHeight, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color(nsColor: .textBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.72), lineWidth: 1)
            )
    }

    private enum ValidationTarget {
        case modelID
        case host
        case port
        case advanced
        case general
    }

    private var validationTarget: ValidationTarget? {
        guard let message = message?.lowercased(), !message.isEmpty else {
            return nil
        }
        if message.contains("model id") || message.contains("modelid") {
            return .modelID
        }
        if message.contains("host") {
            return .host
        }
        if message.contains("port") {
            return .port
        }
        if message.contains("temperature")
            || message.contains("top p")
            || message.contains("top k")
            || message.contains("min p")
            || message.contains("max tokens")
            || message.contains("concurrency")
            || message.contains("prefill")
            || message.contains("prompt cache")
            || message.contains("chat template")
            || message.contains("raw")
            || message.contains("advanced launch")
            || message.contains("quote")
            || message.contains("escape") {
            return .advanced
        }
        return .general
    }

    private var launchCommandPreview: String {
        guard let request = launchCommandPreviewRequest else {
            return t("Complete Model Path, Host, and Port to preview the launch command.", "起動コマンドをプレビューするには、モデルパス、ホスト、ポートを入力してください。")
        }

        return ModelProcessManager.commandPreview(
            for: request,
            executablePath: draft.backend.defaultExecutableName
        )
    }

    private var canCopyLaunchCommandPreview: Bool {
        launchCommandPreviewRequest != nil
    }

    private var launchCommandPreviewRequest: ModelLaunchRequest? {
        let modelID = draft.modelID.trimmingCharacters(in: .whitespacesAndNewlines)
        let host = draft.host.trimmingCharacters(in: .whitespacesAndNewlines)
        let portText = draft.serverPortText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !modelID.isEmpty, !host.isEmpty, let port = Int(portText) else {
            return nil
        }

        return ModelLaunchRequest(
            executablePath: draft.backend.defaultExecutableName,
            backend: draft.backend,
            modelID: modelID,
            host: host,
            port: port,
            enableThinking: draft.enableThinking,
            advancedLaunchOptions: kvCacheSafeModeResult.advancedLaunchOptions
        )
    }
}
