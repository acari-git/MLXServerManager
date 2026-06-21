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
        if let downloads {
            parts.append("Downloads \(downloads)")
        }
        if let likes {
            parts.append("Likes \(likes)")
        }
        if isMLXLikely {
            parts.append("MLX-like")
        }
        return parts.isEmpty ? "No public stats" : parts.joined(separator: " · ")
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
