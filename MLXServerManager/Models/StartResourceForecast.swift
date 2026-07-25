import Foundation

nonisolated struct StartResourceForecast: Equatable, Sendable {
    let profileID: ModelConfig.ID
    let assessment: MultiModelMemoryAssessment
    let suggestedOptions: AdvancedLaunchOptions
    let didAdjustOptions: Bool
    let recommendedTemplate: ModelProfileTemplate?

    func localizedTitle(language: AppLanguage) -> String {
        assessment.title(language: language)
    }

    func localizedDetail(language: AppLanguage) -> String {
        let strings = AppLocalization(language: language)
        let base = assessment.detail(language: language)
        guard let recommendedTemplate else { return base }
        return base + " " + strings.text(
            english: "Review the \(recommendedTemplate.localizedTitle(language: .english)) template as a conservative starting point; no change is applied automatically.",
            japanese: "保守的な開始点として\(recommendedTemplate.localizedTitle(language: .japanese))テンプレートを確認してください。自動適用は行いません。"
        )
    }
}

nonisolated enum StartResourceForecastAdvisor {
    static func make(
        profileID: ModelConfig.ID,
        assessment: MultiModelMemoryAssessment,
        currentOptions: AdvancedLaunchOptions,
        safeModeResult: KVCacheSafeModeResult
    ) -> StartResourceForecast {
        let recommendedTemplate: ModelProfileTemplate?
        switch assessment.level {
        case .critical:
            recommendedTemplate = .memorySaver
        case .caution:
            recommendedTemplate = .memorySaver
        case .safe, .unavailable:
            recommendedTemplate = nil
        }

        return StartResourceForecast(
            profileID: profileID,
            assessment: assessment,
            suggestedOptions: safeModeResult.advancedLaunchOptions ?? currentOptions,
            didAdjustOptions: safeModeResult.didAdjust,
            recommendedTemplate: recommendedTemplate
        )
    }
}
