import Foundation

enum HuggingFaceModelCompatibility: Equatable {
    case supported(label: String)
    case unsupported(reason: String)

    var isSupported: Bool {
        if case .supported = self { return true }
        return false
    }

    var badgeText: String {
        switch self {
        case let .supported(label):
            return label
        case .unsupported:
            return "Unsupported"
        }
    }

    var summaryText: String {
        switch self {
        case let .supported(label):
            return "\(label) tag"
        case let .unsupported(reason):
            return reason
        }
    }
}

struct HuggingFaceDownloadCompatibilityPolicy: Equatable {
    let requiredTag: String
    let displayName: String

    static let mlx = HuggingFaceDownloadCompatibilityPolicy(requiredTag: "mlx", displayName: "MLX")

    func evaluate(tags: [String]) -> HuggingFaceModelCompatibility {
        let normalizedRequiredTag = requiredTag.lowercased()
        let hasRequiredTag = tags.contains { tag in
            tag.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalizedRequiredTag
        }
        if hasRequiredTag {
            return .supported(label: displayName)
        }
        return .unsupported(reason: "Missing \(displayName) tag")
    }
}

struct HuggingFaceSearchResult: Identifiable, Equatable {
    static let compatibilityPolicy: HuggingFaceDownloadCompatibilityPolicy = .mlx

    let id: String
    let downloads: Int?
    let likes: Int?
    let lastModified: String?
    let tags: [String]

    var name: String {
        id.split(separator: "/").last.map(String.init) ?? id
    }

    var owner: String {
        id.split(separator: "/").first.map(String.init) ?? "Unknown"
    }

    var compatibility: HuggingFaceModelCompatibility {
        Self.compatibilityPolicy.evaluate(tags: tags)
    }

    var isSupportedForDownload: Bool {
        compatibility.isSupported
    }

    var isMLXLikely: Bool {
        isSupportedForDownload
    }

    var qualitySummary: String {
        var parts: [String] = [compatibility.summaryText]
        if let downloads {
            parts.append("Downloads \(downloads)")
        }
        if let likes {
            parts.append("Likes \(likes)")
        }
        return parts.joined(separator: " · ")
    }

    func selectionMessage(language: AppLanguage) -> String {
        if isSupportedForDownload {
            return AppLocalization(language: language).text(
                english: "Selected model has the required \(Self.compatibilityPolicy.displayName) tag. Review the details, then press Download.",
                japanese: "必要な\(Self.compatibilityPolicy.displayName)タグを確認しました。内容を確認してからダウンロードしてください。"
            )
        }
        return AppLocalization(language: language).text(
            english: "This model is missing the required \(Self.compatibilityPolicy.displayName) tag and cannot be downloaded in the current mode.",
            japanese: "このモデルには必要な\(Self.compatibilityPolicy.displayName)タグがないため、現在のモードではダウンロードできません。"
        )
    }

    var qualityRank: Int {
        (isSupportedForDownload ? 1_000_000 : 0) + (downloads ?? 0) + ((likes ?? 0) * 100)
    }

    var webURL: String {
        "https://huggingface.co/\(id)"
    }

    var tagsSummary: String {
        tags.isEmpty ? "No tags" : tags.prefix(8).joined(separator: ", ")
    }
}

struct HuggingFaceSearchResponseItem: Decodable {
    let id: String
    let downloads: Int?
    let likes: Int?
    let lastModified: String?
    let tags: [String]?

    func result() -> HuggingFaceSearchResult {
        HuggingFaceSearchResult(
            id: id,
            downloads: downloads,
            likes: likes,
            lastModified: lastModified,
            tags: tags ?? []
        )
    }
}
