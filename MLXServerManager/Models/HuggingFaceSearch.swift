import Foundation

struct HuggingFaceSearchResult: Identifiable, Equatable {
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

    var isMLXLikely: Bool {
        let lowercasedValues = ([id] + tags).map { $0.lowercased() }
        return lowercasedValues.contains { value in
            value.contains("mlx") || value.contains("mlx-community") || value.contains("apple")
        }
    }

    var qualitySummary: String {
        var parts: [String] = []
        if isMLXLikely {
            parts.append("MLX-like")
        }
        if let downloads {
            parts.append("Downloads \(downloads)")
        }
        if let likes {
            parts.append("Likes \(likes)")
        }
        return parts.isEmpty ? "No public stats" : parts.joined(separator: " · ")
    }

    var selectionWarning: String {
        if isMLXLikely {
            return "Selected MLX-like model. Review the download form, then press Download."
        }
        return "Selected model. It may not be MLX-ready; confirm the repository before downloading."
    }

    var qualityRank: Int {
        (isMLXLikely ? 1_000_000 : 0) + (downloads ?? 0) + ((likes ?? 0) * 100)
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
