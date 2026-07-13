import SwiftUI

struct BenchmarkComparisonView: View {
    @ObservedObject var viewModel: AppViewModel
    @Binding var isPresented: Bool
    @State private var selectedUseCase: BenchmarkUseCase = .chat

    private var strings: AppLocalization {
        AppLocalization(language: viewModel.settings.uiLanguage)
    }

    private func t(_ english: String, _ japanese: String) -> String {
        strings.text(english: english, japanese: japanese)
    }

    private var rows: [BenchmarkComparisonRow] {
        viewModel.rankedBenchmarkRows(for: selectedUseCase)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(t("Model Comparison", "モデル比較"))
                        .font(.title3.weight(.semibold))
                    Text(t(
                        "Results are ranked only for this Mac. Re-run stale or single-sample results before making a final choice.",
                        "このMacでの結果だけを順位付けします。最終判断前に、古い結果や単回測定は再測定してください。"
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                Button(t("Done", "完了")) {
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()

            Picker(t("Use case", "用途"), selection: $selectedUseCase) {
                ForEach(BenchmarkUseCase.allCases, id: \.self) { useCase in
                    Text(useCase.localizedTitle(language: viewModel.settings.uiLanguage))
                        .tag(useCase)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.bottom, 12)

            Divider()

            Table(rows) {
                TableColumn(t("Model", "モデル")) { row in
                    HStack(spacing: 6) {
                        if row.recommendedUseCases.contains(selectedUseCase) {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(.green)
                                .help(t("Recommended for this use case", "この用途のおすすめ"))
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.displayName)
                                .lineLimit(1)
                            Text(row.session.preset.localizedTitle(language: viewModel.settings.uiLanguage))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .width(min: 220, ideal: 300)

                TableColumn(t("Score", "スコア")) { row in
                    Text(row.score(for: selectedUseCase).map { "\($0)/10" } ?? "-")
                        .monospacedDigit()
                }
                .width(70)

                TableColumn(t("Median output", "出力中央値")) { row in
                    Text(row.session.aggregate.medianOutputTokensPerSecond.map { String(format: "%.1f tok/s", $0) } ?? "-")
                        .monospacedDigit()
                }
                .width(105)

                TableColumn("TTFT") { row in
                    Text(row.session.aggregate.medianTTFTMS.map { String(format: "%.0f ms", $0) } ?? "-")
                        .monospacedDigit()
                }
                .width(80)

                TableColumn(t("Stability", "安定度")) { row in
                    Text(row.session.aggregate.stabilityPercent.map { "\($0)%" }
                        ?? row.session.aggregate.stabilityLevel.localizedTitle(language: viewModel.settings.uiLanguage))
                        .monospacedDigit()
                }
                .width(90)

                TableColumn(t("Samples", "測定")) { row in
                    Text("\(row.session.aggregate.successfulSampleCount)/\(row.session.aggregate.sampleCount)")
                        .monospacedDigit()
                }
                .width(65)
            }
            .overlay {
                if rows.isEmpty {
                    ContentUnavailableView(
                        t("No comparable results", "比較できる結果がありません"),
                        systemImage: "chart.bar.xaxis",
                        description: Text(t(
                            "Run Standard or Detailed Benchmark on at least two models.",
                            "2つ以上のモデルで標準または詳細ベンチマークを実行してください。"
                        ))
                    )
                }
            }
        }
        .frame(minWidth: 820, idealWidth: 920, minHeight: 460, idealHeight: 540)
    }
}
