import Foundation

nonisolated struct BenchmarkProfileTuningRecommendation: Identifiable, Equatable, Sendable {
    let profileID: ModelConfig.ID
    let useCase: BenchmarkUseCase
    let template: ModelProfileTemplate
    let score: Int
    let medianTTFTMS: Double?
    let medianOutputTokensPerSecond: Double?
    let stabilityPercent: Int?
    let medianManagedMemoryGigabytes: Double?
    let reasonCodes: [BenchmarkScoreReasonCode]
    let executionFingerprint: String?

    var id: String { "\(profileID):\(useCase.rawValue)" }

    func localizedReason(language: AppLanguage) -> String {
        let strings = AppLocalization(language: language)
        let ttft = medianTTFTMS.map { String(format: "%.0f ms", $0) }
            ?? strings.text(english: "unavailable", japanese: "不明")
        let speed = medianOutputTokensPerSecond.map { String(format: "%.1f tok/s", $0) }
            ?? strings.text(english: "unavailable", japanese: "不明")
        let stability = stabilityPercent.map { "\($0)%" }
            ?? strings.text(english: "unavailable", japanese: "不明")
        return strings.text(
            english: "Score \(score)/10, median TTFT \(ttft), generation \(speed), stability \(stability). The \(template.localizedTitle(language: .english)) template is a reviewable starting point, not a guaranteed optimization.",
            japanese: "スコア\(score)/10、TTFT中央値\(ttft)、生成速度\(speed)、安定性\(stability)。\(template.localizedTitle(language: .japanese))テンプレートは確認可能な開始点であり、性能改善を保証しません。"
        )
    }
}

nonisolated enum BenchmarkProfileTuningAdvisor {
    static func recommendation(
        row: BenchmarkComparisonRow?,
        useCase: BenchmarkUseCase
    ) -> BenchmarkProfileTuningRecommendation? {
        guard let row,
              !row.isStale,
              row.session.aggregate.successfulSampleCount >= 2,
              let scoreEntry = row.session.aggregate.medianUseCaseScores.first(where: { $0.useCase == useCase }) else {
            return nil
        }

        let aggregate = row.session.aggregate
        let reasonCodes = scoreEntry.reasonCodes
        let memoryConstrained = reasonCodes.contains(.memoryTight)
            || reasonCodes.contains(.memoryLimited)
        let unstable = (aggregate.stabilityPercent ?? 0) < 70
        let template: ModelProfileTemplate

        if memoryConstrained || unstable {
            template = .memorySaver
        } else {
            switch useCase {
            case .chat:
                template = .balanced
            case .coding:
                let speed = aggregate.medianOutputTokensPerSecond ?? 0
                template = scoreEntry.score >= 7 && speed >= 8
                    ? .throughput
                    : .balanced
            case .agent:
                template = scoreEntry.score >= 7 && (aggregate.stabilityPercent ?? 0) >= 85
                    ? .balanced
                    : .memorySaver
            }
        }

        return BenchmarkProfileTuningRecommendation(
            profileID: row.profileID,
            useCase: useCase,
            template: template,
            score: scoreEntry.score,
            medianTTFTMS: aggregate.medianTTFTMS,
            medianOutputTokensPerSecond: aggregate.medianOutputTokensPerSecond,
            stabilityPercent: aggregate.stabilityPercent,
            medianManagedMemoryGigabytes: aggregate.medianManagedMemoryGigabytes,
            reasonCodes: reasonCodes,
            executionFingerprint: row.session.executionFingerprint
        )
    }

    static func recommendations(
        row: BenchmarkComparisonRow?
    ) -> [BenchmarkProfileTuningRecommendation] {
        BenchmarkUseCase.allCases.compactMap { recommendation(row: row, useCase: $0) }
    }
}
