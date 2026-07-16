import Foundation

nonisolated enum BenchmarkPreset: String, Codable, CaseIterable, Identifiable, Hashable {
    case quick
    case standard
    case detailed

    var id: String { rawValue }

    var sampleCount: Int {
        switch self {
        case .quick: 1
        case .standard: 3
        case .detailed: 5
        }
    }

    var includesAgentProbes: Bool {
        self != .quick
    }

    var usesWarmup: Bool {
        self != .quick
    }

    func localizedTitle(language: AppLanguage) -> String {
        let strings = AppLocalization(language: language)
        switch self {
        case .quick:
            return strings.text(english: "Quick", japanese: "クイック")
        case .standard:
            return strings.text(english: "Standard", japanese: "標準")
        case .detailed:
            return strings.text(english: "Detailed", japanese: "詳細")
        }
    }

    func localizedDescription(language: AppLanguage) -> String {
        let strings = AppLocalization(language: language)
        switch self {
        case .quick:
            return strings.text(
                english: "One speed sample. Best for a fast health check.",
                japanese: "速度を1回測定します。短時間の動作確認向けです。"
            )
        case .standard:
            return strings.text(
                english: "Three complete samples with agent probes. Uses medians for comparison.",
                japanese: "Agentテストを含む完全測定を3回行い、中央値で比較します。"
            )
        case .detailed:
            return strings.text(
                english: "Five complete samples for a stronger stability estimate.",
                japanese: "完全測定を5回行い、より確かな安定度を算出します。"
            )
        }
    }
}

nonisolated enum BenchmarkStabilityLevel: String, Codable, Equatable {
    case high
    case medium
    case low
    case unavailable

    func localizedTitle(language: AppLanguage) -> String {
        let strings = AppLocalization(language: language)
        switch self {
        case .high: return strings.text(english: "High", japanese: "高い")
        case .medium: return strings.text(english: "Medium", japanese: "標準")
        case .low: return strings.text(english: "Low", japanese: "低い")
        case .unavailable: return strings.text(english: "Not enough data", japanese: "データ不足")
        }
    }
}

nonisolated struct BenchmarkAggregateMetrics: Codable, Equatable {
    let sampleCount: Int
    let successfulSampleCount: Int
    let medianTTFTMS: Double?
    let medianTotalLatencyMS: Double?
    let medianOutputTokensPerSecond: Double?
    let medianManagedMemoryGigabytes: Double?
    let stabilityPercent: Int?
    let stabilityLevel: BenchmarkStabilityLevel
    let medianUseCaseScores: [BenchmarkUseCaseScore]

    var successFraction: Double {
        guard sampleCount > 0 else { return 0 }
        return Double(successfulSampleCount) / Double(sampleCount)
    }
}

nonisolated struct BenchmarkSessionResult: Codable, Identifiable, Equatable {
    let id: UUID
    let timestamp: Date
    let profileID: String
    let modelID: String
    let selectedProfileName: String
    let preset: BenchmarkPreset
    let executionFingerprint: String?
    let samples: [BenchmarkResult]
    let aggregate: BenchmarkAggregateMetrics

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        profileID: String,
        modelID: String,
        selectedProfileName: String,
        preset: BenchmarkPreset,
        executionFingerprint: String? = nil,
        samples: [BenchmarkResult]
    ) {
        self.id = id
        self.timestamp = timestamp
        self.profileID = profileID
        self.modelID = modelID
        self.selectedProfileName = selectedProfileName
        self.preset = preset
        self.executionFingerprint = executionFingerprint
        self.samples = samples
        aggregate = BenchmarkSessionAnalyzer.aggregate(
            samples: samples,
            includesAgentProbes: preset.includesAgentProbes
        )
    }

    var representativeResult: BenchmarkResult? {
        BenchmarkSessionAnalyzer.representativeResult(
            samples: samples,
            medianOutputTokensPerSecond: aggregate.medianOutputTokensPerSecond
        )
    }

    var worstThermalState: BenchmarkThermalState? {
        samples.compactMap { $0.hostSnapshot?.thermalState }.max()
    }
}

nonisolated enum BenchmarkComparisonExclusionReason: String, Equatable, Hashable {
    case suiteChanged
    case chipChanged
    case backendChanged
    case executionConfigurationChanged
    case thermalPressure
    case insufficientSuccessfulSamples

    func localizedTitle(language: AppLanguage) -> String {
        let strings = AppLocalization(language: language)
        return switch self {
        case .suiteChanged:
            strings.text(
                english: "The benchmark suite has changed",
                japanese: "ベンチマーク内容が更新されています"
            )
        case .chipChanged:
            strings.text(
                english: "The Mac hardware does not match",
                japanese: "測定時とMacの構成が異なります"
            )
        case .backendChanged:
            strings.text(
                english: "The inference backend has changed",
                japanese: "推論バックエンドが変更されています"
            )
        case .executionConfigurationChanged:
            strings.text(
                english: "The model launch settings have changed",
                japanese: "モデルの起動設定が変更されています"
            )
        case .thermalPressure:
            strings.text(
                english: "The Mac was under high thermal pressure",
                japanese: "測定時のMacが高温状態でした"
            )
        case .insufficientSuccessfulSamples:
            strings.text(
                english: "At least two successful samples are required",
                japanese: "成功した測定が2回以上必要です"
            )
        }
    }
}

nonisolated struct BenchmarkComparisonRow: Identifiable, Equatable {
    let profileID: String
    let displayName: String
    let session: BenchmarkSessionResult
    let exclusionReasons: [BenchmarkComparisonExclusionReason]
    let recommendedUseCases: Set<BenchmarkUseCase>

    var id: String { profileID }
    var isStale: Bool { !exclusionReasons.isEmpty }

    func score(for useCase: BenchmarkUseCase) -> Int? {
        session.aggregate.medianUseCaseScores.first(where: { $0.useCase == useCase })?.score
    }

    func localizedExclusionSummary(language: AppLanguage) -> String? {
        guard !exclusionReasons.isEmpty else { return nil }
        return exclusionReasons
            .map { $0.localizedTitle(language: language) }
            .joined(separator: language.resolved == .english ? "; " : "、")
    }
}

nonisolated enum BenchmarkSessionAnalyzer {
    static func aggregate(
        samples: [BenchmarkResult],
        includesAgentProbes: Bool = true
    ) -> BenchmarkAggregateMetrics {
        let successfulSamples = samples.filter { result in
            result.phase == .success && result.speedMetrics?.errorMessage == nil
        }
        let speedMetrics = successfulSamples.compactMap(\.speedMetrics)
        let ttftValues = speedMetrics.compactMap(\.ttftMS)
        let latencyValues = speedMetrics.compactMap(\.totalLatencyMS)
        let speedValues = speedMetrics.compactMap(\.outputTokensPerSecond)
        let memoryValues = speedMetrics.compactMap(\.managedMemoryGigabytes)
        let stabilityInputs = [
            robustStability(values: ttftValues),
            robustStability(values: speedValues)
        ].compactMap { $0 }
        let stabilityPercent = stabilityInputs.isEmpty
            ? nil
            : Int((stabilityInputs.reduce(0, +) / Double(stabilityInputs.count)).rounded())

        return BenchmarkAggregateMetrics(
            sampleCount: samples.count,
            successfulSampleCount: successfulSamples.count,
            medianTTFTMS: median(ttftValues),
            medianTotalLatencyMS: median(latencyValues),
            medianOutputTokensPerSecond: median(speedValues),
            medianManagedMemoryGigabytes: median(memoryValues),
            stabilityPercent: stabilityPercent,
            stabilityLevel: stabilityLevel(percent: stabilityPercent, sampleCount: samples.count),
            medianUseCaseScores: BenchmarkUseCase.allCases.compactMap { useCase in
                if useCase == .agent && !includesAgentProbes {
                    return nil
                }
                let values = successfulSamples.compactMap { result in
                    result.useCaseScores.first(where: { $0.useCase == useCase })?.score
                }
                guard let value = median(values.map(Double.init)) else { return nil }
                return BenchmarkUseCaseScore(
                    useCase: useCase,
                    score: Int(value.rounded()),
                    reasonCodes: aggregateReasonCodes(samples: successfulSamples, useCase: useCase)
                )
            }
        )
    }

    static func representativeResult(
        samples: [BenchmarkResult],
        medianOutputTokensPerSecond: Double?
    ) -> BenchmarkResult? {
        let successful = samples.filter { $0.phase == .success }
        guard let medianOutputTokensPerSecond else {
            return successful.first ?? samples.first
        }
        return successful.min { lhs, rhs in
            abs((lhs.speedMetrics?.outputTokensPerSecond ?? 0) - medianOutputTokensPerSecond)
                < abs((rhs.speedMetrics?.outputTokensPerSecond ?? 0) - medianOutputTokensPerSecond)
        } ?? samples.first
    }

    static func comparisonRows(
        models: [ModelConfig],
        sessionsByProfileID: [String: BenchmarkSessionResult],
        currentSuiteVersion: String = BenchmarkSuite.version,
        currentChipName: String? = nil,
        currentExecutionFingerprintsByProfileID: [String: String]? = nil
    ) -> [BenchmarkComparisonRow] {
        var rows = models.compactMap { model -> BenchmarkComparisonRow? in
            guard let session = sessionsByProfileID[model.id] else { return nil }
            let host = session.representativeResult?.hostSnapshot
            let expectedExecutionFingerprint = currentExecutionFingerprintsByProfileID?[model.id]
            let executionConfigurationChanged = expectedExecutionFingerprint.map {
                session.executionFingerprint != $0
            } ?? false
            var exclusionReasons: [BenchmarkComparisonExclusionReason] = []
            if session.representativeResult?.suiteVersion != currentSuiteVersion {
                exclusionReasons.append(.suiteChanged)
            }
            if currentChipName != nil && host?.chipName != currentChipName {
                exclusionReasons.append(.chipChanged)
            }
            if host?.resolvedBackend != model.resolvedBackend {
                exclusionReasons.append(.backendChanged)
            }
            if executionConfigurationChanged {
                exclusionReasons.append(.executionConfigurationChanged)
            }
            if session.worstThermalState?.excludesRecommendation == true {
                exclusionReasons.append(.thermalPressure)
            }
            if session.aggregate.successfulSampleCount < 2 {
                exclusionReasons.append(.insufficientSuccessfulSamples)
            }
            return BenchmarkComparisonRow(
                profileID: model.id,
                displayName: model.displayName,
                session: session,
                exclusionReasons: exclusionReasons,
                recommendedUseCases: []
            )
        }

        let recommendations = Dictionary(uniqueKeysWithValues: BenchmarkUseCase.allCases.compactMap { useCase in
            ranked(rows: rows, for: useCase).first.map { (useCase, $0.profileID) }
        })

        rows = rows.map { row in
            BenchmarkComparisonRow(
                profileID: row.profileID,
                displayName: row.displayName,
                session: row.session,
                exclusionReasons: row.exclusionReasons,
                recommendedUseCases: Set(recommendations.compactMap { key, value in
                    value == row.profileID ? key : nil
                })
            )
        }
        return rows
    }

    static func ranked(
        rows: [BenchmarkComparisonRow],
        for useCase: BenchmarkUseCase
    ) -> [BenchmarkComparisonRow] {
        rows.filter { !$0.isStale && $0.score(for: useCase) != nil }
            .sorted { lhs, rhs in
                let lhsScore = lhs.score(for: useCase) ?? 0
                let rhsScore = rhs.score(for: useCase) ?? 0
                if lhsScore != rhsScore { return lhsScore > rhsScore }
                if lhs.session.aggregate.successFraction != rhs.session.aggregate.successFraction {
                    return lhs.session.aggregate.successFraction > rhs.session.aggregate.successFraction
                }
                let lhsStability = lhs.session.aggregate.stabilityPercent ?? -1
                let rhsStability = rhs.session.aggregate.stabilityPercent ?? -1
                if lhsStability != rhsStability { return lhsStability > rhsStability }
                let lhsSpeed = lhs.session.aggregate.medianOutputTokensPerSecond ?? -1
                let rhsSpeed = rhs.session.aggregate.medianOutputTokensPerSecond ?? -1
                if lhsSpeed != rhsSpeed { return lhsSpeed > rhsSpeed }
                let lhsTTFT = lhs.session.aggregate.medianTTFTMS ?? .greatestFiniteMagnitude
                let rhsTTFT = rhs.session.aggregate.medianTTFTMS ?? .greatestFiniteMagnitude
                return lhsTTFT < rhsTTFT
            }
    }

    private static func median(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let middle = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[middle - 1] + sorted[middle]) / 2
        }
        return sorted[middle]
    }

    private static func robustStability(values: [Double]) -> Double? {
        guard values.count >= 2, let center = median(values), abs(center) > 0.000_001 else {
            return nil
        }
        let deviations = values.map { abs($0 - center) }
        guard let medianDeviation = median(deviations) else { return nil }
        let relativeDeviation = medianDeviation / abs(center)
        return max(0, min(100, 100 * (1 - relativeDeviation * 4)))
    }

    private static func stabilityLevel(
        percent: Int?,
        sampleCount: Int
    ) -> BenchmarkStabilityLevel {
        guard sampleCount >= 2, let percent else { return .unavailable }
        if percent >= 90 { return .high }
        if percent >= 70 { return .medium }
        return .low
    }

    private static func aggregateReasonCodes(
        samples: [BenchmarkResult],
        useCase: BenchmarkUseCase
    ) -> [BenchmarkScoreReasonCode] {
        let codes = samples.flatMap { result in
            result.useCaseScores.first(where: { $0.useCase == useCase })?.reasonCodes ?? []
        }
        var seen = Set<BenchmarkScoreReasonCode>()
        return codes.filter { seen.insert($0).inserted }.prefix(3).map { $0 }
    }
}
