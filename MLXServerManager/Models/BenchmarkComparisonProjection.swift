import Foundation

nonisolated struct BenchmarkComparisonProjection {
    let rows: [BenchmarkComparisonRow]
    let rowsByProfileID: [ModelConfig.ID: BenchmarkComparisonRow]
    let rankedRowsByUseCase: [BenchmarkUseCase: [BenchmarkComparisonRow]]
    let comparableRowCount: Int

    init(
        models: [ModelConfig],
        sessionsByProfileID: [ModelConfig.ID: BenchmarkSessionResult],
        currentChipName: String?,
        currentExecutionFingerprintsByProfileID: [ModelConfig.ID: String]
    ) {
        let rows = BenchmarkSessionAnalyzer.comparisonRows(
            models: models,
            sessionsByProfileID: sessionsByProfileID,
            currentChipName: currentChipName,
            currentExecutionFingerprintsByProfileID: currentExecutionFingerprintsByProfileID
        )
        self.rows = rows

        var rowsByProfileID: [ModelConfig.ID: BenchmarkComparisonRow] = [:]
        for row in rows where rowsByProfileID[row.profileID] == nil {
            rowsByProfileID[row.profileID] = row
        }
        self.rowsByProfileID = rowsByProfileID
        self.rankedRowsByUseCase = Dictionary(
            uniqueKeysWithValues: BenchmarkUseCase.allCases.map { useCase in
                (useCase, BenchmarkSessionAnalyzer.ranked(rows: rows, for: useCase))
            }
        )
        self.comparableRowCount = rows.lazy.filter { !$0.isStale }.count
    }

    func row(for profileID: ModelConfig.ID) -> BenchmarkComparisonRow? {
        rowsByProfileID[profileID]
    }

    func rankedRows(for useCase: BenchmarkUseCase) -> [BenchmarkComparisonRow] {
        rankedRowsByUseCase[useCase] ?? []
    }
}
