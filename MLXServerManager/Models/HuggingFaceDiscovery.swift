import Foundation

nonisolated enum HuggingFaceDiscoverySort: String, CaseIterable, Identifiable, Sendable {
    case recommended
    case downloads
    case likes
    case recentlyUpdated
    case name

    var id: String { rawValue }

    func localizedTitle(language: AppLanguage) -> String {
        let strings = AppLocalization(language: language)
        switch self {
        case .recommended:
            return strings.text(english: "Recommended", japanese: "おすすめ")
        case .downloads:
            return strings.text(english: "Downloads", japanese: "ダウンロード数")
        case .likes:
            return strings.text(english: "Likes", japanese: "いいね数")
        case .recentlyUpdated:
            return strings.text(english: "Recently Updated", japanese: "更新が新しい順")
        case .name:
            return strings.text(english: "Name", japanese: "名前")
        }
    }
}

nonisolated struct HuggingFaceDiscoveryFilter: Equatable, Sendable {
    var showOnlySupported: Bool
    var minimumDownloads: Int
    var sort: HuggingFaceDiscoverySort

    static let defaults = HuggingFaceDiscoveryFilter(
        showOnlySupported: false,
        minimumDownloads: 0,
        sort: .recommended
    )

    init(
        showOnlySupported: Bool,
        minimumDownloads: Int,
        sort: HuggingFaceDiscoverySort
    ) {
        self.showOnlySupported = showOnlySupported
        self.minimumDownloads = max(0, minimumDownloads)
        self.sort = sort
    }
}

nonisolated enum HuggingFaceDiscoveryProjection {
    static func project(
        results: [HuggingFaceSearchResult],
        filter: HuggingFaceDiscoveryFilter
    ) -> [HuggingFaceSearchResult] {
        results
            .filter { result in
                (!filter.showOnlySupported || result.isSupportedForDownload)
                    && (result.downloads ?? 0) >= filter.minimumDownloads
            }
            .sorted { lhs, rhs in
                ordered(lhs, before: rhs, sort: filter.sort)
            }
    }

    private static func ordered(
        _ lhs: HuggingFaceSearchResult,
        before rhs: HuggingFaceSearchResult,
        sort: HuggingFaceDiscoverySort
    ) -> Bool {
        switch sort {
        case .recommended:
            if lhs.isSupportedForDownload != rhs.isSupportedForDownload {
                return lhs.isSupportedForDownload
            }
            return compareDescending(
                lhs: lhs.qualityRank,
                rhs: rhs.qualityRank,
                lhsResult: lhs,
                rhsResult: rhs
            )
        case .downloads:
            let lhsDownloads = lhs.downloads ?? 0
            let rhsDownloads = rhs.downloads ?? 0
            if lhsDownloads != rhsDownloads {
                return lhsDownloads > rhsDownloads
            }
            let lhsLikes = lhs.likes ?? 0
            let rhsLikes = rhs.likes ?? 0
            if lhsLikes != rhsLikes {
                return lhsLikes > rhsLikes
            }
            return stableNameOrder(lhs, rhs)
        case .likes:
            let lhsLikes = lhs.likes ?? 0
            let rhsLikes = rhs.likes ?? 0
            if lhsLikes != rhsLikes {
                return lhsLikes > rhsLikes
            }
            let lhsDownloads = lhs.downloads ?? 0
            let rhsDownloads = rhs.downloads ?? 0
            if lhsDownloads != rhsDownloads {
                return lhsDownloads > rhsDownloads
            }
            return stableNameOrder(lhs, rhs)
        case .recentlyUpdated:
            let lhsDate = parsedDate(lhs.lastModified)
            let rhsDate = parsedDate(rhs.lastModified)
            if lhsDate != rhsDate {
                return (lhsDate ?? .distantPast) > (rhsDate ?? .distantPast)
            }
            return stableNameOrder(lhs, rhs)
        case .name:
            return stableNameOrder(lhs, rhs)
        }
    }

    private static func compareDescending(
        lhs: Int,
        rhs: Int,
        lhsResult: HuggingFaceSearchResult,
        rhsResult: HuggingFaceSearchResult
    ) -> Bool {
        if lhs != rhs {
            return lhs > rhs
        }
        let lhsDate = parsedDate(lhsResult.lastModified)
        let rhsDate = parsedDate(rhsResult.lastModified)
        if lhsDate != rhsDate {
            return (lhsDate ?? .distantPast) > (rhsDate ?? .distantPast)
        }
        return stableNameOrder(lhsResult, rhsResult)
    }

    private static func stableNameOrder(
        _ lhs: HuggingFaceSearchResult,
        _ rhs: HuggingFaceSearchResult
    ) -> Bool {
        let lhsName = lhs.id.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        let rhsName = rhs.id.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        if lhsName != rhsName {
            return lhsName < rhsName
        }
        return lhs.id < rhs.id
    }

    static func parsedDate(_ value: String?) -> Date? {
        guard let value, !value.isEmpty else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) {
            return date
        }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }
}

extension HuggingFaceSearchResult {
    func discoveryReason(language: AppLanguage) -> String {
        let strings = AppLocalization(language: language)
        var reasons: [String] = []
        reasons.append(
            isSupportedForDownload
                ? strings.text(english: "MLX tag verified", japanese: "MLXタグ確認済み")
                : strings.text(english: "MLX tag missing", japanese: "MLXタグなし")
        )
        if let downloads {
            reasons.append(strings.text(
                english: "\(downloads) downloads",
                japanese: "\(downloads)ダウンロード"
            ))
        }
        if let likes {
            reasons.append(strings.text(
                english: "\(likes) likes",
                japanese: "\(likes)いいね"
            ))
        }
        if let lastModified,
           HuggingFaceDiscoveryProjection.parsedDate(lastModified) != nil {
            reasons.append(strings.text(
                english: "updated \(lastModified)",
                japanese: "更新 \(lastModified)"
            ))
        }
        return reasons.joined(separator: " · ")
    }
}
