import SwiftUI

private struct LaunchPlanEditorStepDraft: Identifiable, Equatable {
    let profileID: String
    var isRequired: Bool

    var id: String { profileID }
}

struct LaunchPlanEditorView: View {
    let models: [ModelConfig]
    let existingPlan: LaunchPlanDefinition?
    let language: AppLanguage
    let onSave: (LaunchPlanDefinition) -> Void
    let onCancel: () -> Void

    @State private var name: String
    @State private var steps: [LaunchPlanEditorStepDraft]
    @State private var validationMessage: String?

    init(
        models: [ModelConfig],
        existingPlan: LaunchPlanDefinition?,
        language: AppLanguage,
        onSave: @escaping (LaunchPlanDefinition) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.models = models
        self.existingPlan = existingPlan
        self.language = language
        self.onSave = onSave
        self.onCancel = onCancel
        _name = State(initialValue: existingPlan?.name ?? "")
        _steps = State(initialValue: existingPlan?.steps.map {
            LaunchPlanEditorStepDraft(
                profileID: $0.profileID,
                isRequired: $0.isRequired
            )
        } ?? [])
    }

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
                    nameSection
                    selectedProfilesSection
                    availableProfilesSection
                    safetySection
                }
                .padding(18)
            }

            Divider()

            footer
                .padding(18)
        }
        .frame(minWidth: 720, minHeight: 600)
        .accessibilityIdentifier("launch-plan-editor")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(existingPlan == nil
                ? t("New Launch Plan", "新しい起動プラン")
                : t("Edit Launch Plan", "起動プランを編集"))
                .font(.title3.weight(.semibold))
            Text(t(
                "A Launch Plan is a saved ordered definition. Saving it does not start or stop any server.",
                "起動プランは順序付きの保存定義です。保存してもサーバーの起動・停止は行いません。"
            ))
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private var nameSection: some View {
        GroupBox {
            TextField(t("Plan name", "プラン名"), text: $name)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("launch-plan-editor-name")
                .padding(.vertical, 6)
        } label: {
            Label(t("Name", "名前"), systemImage: "textformat")
        }
    }

    private var selectedProfilesSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                if steps.isEmpty {
                    Text(t(
                        "Add at least one registered profile from the list below.",
                        "下の一覧から登録済みプロファイルを1件以上追加してください。"
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
                } else {
                    ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                        selectedRow(index: index, step: step)
                        if index < steps.count - 1 {
                            Divider()
                        }
                    }
                }
            }
            .padding(.vertical, 6)
        } label: {
            Label(t("Ordered Steps", "起動順序"), systemImage: "list.number")
        }
        .accessibilityIdentifier("launch-plan-editor-steps")
    }

    private func selectedRow(
        index: Int,
        step: LaunchPlanEditorStepDraft
    ) -> some View {
        HStack(spacing: 10) {
            Text("\(index + 1)")
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(modelName(for: step.profileID))
                    .font(.callout.weight(.medium))
                Text(modelEndpoint(for: step.profileID))
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Toggle(
                t("Required", "必須"),
                isOn: Binding(
                    get: { steps[index].isRequired },
                    set: { steps[index].isRequired = $0 }
                )
            )
            .toggleStyle(.checkbox)
            .fixedSize()

            Button {
                moveStep(from: index, offset: -1)
            } label: {
                Image(systemName: "chevron.up")
            }
            .buttonStyle(.borderless)
            .disabled(index == 0)
            .help(t("Move earlier", "前へ移動"))

            Button {
                moveStep(from: index, offset: 1)
            } label: {
                Image(systemName: "chevron.down")
            }
            .buttonStyle(.borderless)
            .disabled(index == steps.count - 1)
            .help(t("Move later", "後へ移動"))

            Button(role: .destructive) {
                steps.remove(at: index)
            } label: {
                Image(systemName: "minus.circle")
            }
            .buttonStyle(.borderless)
            .help(t("Remove from plan", "プランから削除"))
        }
        .padding(.vertical, 4)
    }

    private var availableProfilesSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                let available = models.filter { model in
                    !steps.contains(where: { $0.profileID == model.id })
                }
                if available.isEmpty {
                    Text(t(
                        "All registered profiles are already included.",
                        "登録済みプロファイルはすべて追加済みです。"
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
                } else {
                    ForEach(available) { model in
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(model.displayName)
                                    .font(.callout.weight(.medium))
                                Text("\(model.host):\(model.serverPort)")
                                    .font(.caption2.monospaced())
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button {
                                steps.append(LaunchPlanEditorStepDraft(
                                    profileID: model.id,
                                    isRequired: true
                                ))
                            } label: {
                                Label(t("Add", "追加"), systemImage: "plus")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .padding(.vertical, 6)
        } label: {
            Label(t("Registered Profiles", "登録済みプロファイル"), systemImage: "square.stack.3d.up")
        }
    }

    private var safetySection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 7) {
                safetyLine(
                    t(
                        "Execution remains explicit and sequential.",
                        "実行は明示操作で、順番に行われます。"
                    )
                )
                safetyLine(
                    t(
                        "Existing network-exposure, compatibility, endpoint, model, and memory guardrails still apply.",
                        "既存のネットワーク公開、互換性、エンドポイント、モデル、メモリの安全確認はそのまま適用されます。"
                    )
                )
                safetyLine(
                    t(
                        "Already-running profiles and external processes are not taken over by the plan.",
                        "既に実行中のプロファイルや外部プロセスの所有権をプランが取得することはありません。"
                    )
                )
            }
            .padding(.vertical, 6)
        } label: {
            Label(t("Safety Boundary", "安全境界"), systemImage: "lock.shield")
        }
    }

    private func safetyLine(_ text: String) -> some View {
        Label(text, systemImage: "checkmark.circle")
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let validationMessage {
                Label(validationMessage, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            HStack {
                Spacer()
                Button(t("Cancel", "キャンセル"), action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button(t("Save Plan", "プランを保存"), action: save)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .accessibilityIdentifier("launch-plan-editor-save")
            }
        }
    }

    private func save() {
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedName.isEmpty else {
            validationMessage = t(
                "Enter a launch-plan name.",
                "起動プラン名を入力してください。"
            )
            return
        }
        guard !steps.isEmpty else {
            validationMessage = t(
                "Add at least one profile.",
                "プロファイルを1件以上追加してください。"
            )
            return
        }
        guard Set(steps.map(\.profileID)).count == steps.count else {
            validationMessage = t(
                "The plan contains duplicate profiles.",
                "プランに同じプロファイルが重複しています。"
            )
            return
        }
        let now = Date()
        onSave(LaunchPlanDefinition(
            id: existingPlan?.id ?? UUID(),
            name: normalizedName,
            steps: steps.map {
                LaunchPlanStep(
                    profileID: $0.profileID,
                    isRequired: $0.isRequired
                )
            },
            createdAt: existingPlan?.createdAt ?? now,
            updatedAt: now
        ))
    }

    private func moveStep(from index: Int, offset: Int) {
        let destination = index + offset
        guard steps.indices.contains(destination) else { return }
        let step = steps.remove(at: index)
        steps.insert(step, at: destination)
    }

    private func modelName(for profileID: String) -> String {
        models.first(where: { $0.id == profileID })?.displayName
            ?? t("Missing profile", "削除済みプロファイル")
    }

    private func modelEndpoint(for profileID: String) -> String {
        guard let model = models.first(where: { $0.id == profileID }) else {
            return t("Profile unavailable", "プロファイルなし")
        }
        return "\(model.host):\(model.serverPort) · \(model.resolvedBackend.rawValue)"
    }
}
