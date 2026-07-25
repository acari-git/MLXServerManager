import XCTest
@testable import MLXServerManager

final class HuggingFaceDiscoveryTests: XCTestCase {
    func testRecommendedPrioritizesSupportedResultsThenQuality() {
        let results = [
            makeResult(id: "owner/unsupported-popular", downloads: 1_000_000, likes: 2_000, tags: []),
            makeResult(id: "owner/mlx-small", downloads: 500, likes: 2, tags: ["mlx"]),
            makeResult(id: "owner/mlx-popular", downloads: 2_000, likes: 20, tags: ["mlx"])
        ]

        let projected = HuggingFaceDiscoveryProjection.project(
            results: results,
            filter: .defaults
        )

        XCTAssertEqual(projected.map(\.id), [
            "owner/mlx-popular",
            "owner/mlx-small",
            "owner/unsupported-popular"
        ])
    }

    func testFiltersByCompatibilityAndMinimumDownloadsWithoutChangingInput() {
        let results = [
            makeResult(id: "owner/a", downloads: 50, likes: 0, tags: ["mlx"]),
            makeResult(id: "owner/b", downloads: 500, likes: 0, tags: []),
            makeResult(id: "owner/c", downloads: 1_500, likes: 0, tags: ["mlx"])
        ]
        let filter = HuggingFaceDiscoveryFilter(
            showOnlySupported: true,
            minimumDownloads: 100,
            sort: .downloads
        )

        let projected = HuggingFaceDiscoveryProjection.project(results: results, filter: filter)

        XCTAssertEqual(projected.map(\.id), ["owner/c"])
        XCTAssertEqual(results.map(\.id), ["owner/a", "owner/b", "owner/c"])
    }

    func testDownloadAndLikeSortsUseStableTieBreakers() {
        let results = [
            makeResult(id: "owner/zeta", downloads: 100, likes: 10, tags: ["mlx"]),
            makeResult(id: "owner/alpha", downloads: 100, likes: 10, tags: ["mlx"]),
            makeResult(id: "owner/middle", downloads: 200, likes: 1, tags: ["mlx"])
        ]

        let byDownloads = HuggingFaceDiscoveryProjection.project(
            results: results,
            filter: HuggingFaceDiscoveryFilter(
                showOnlySupported: false,
                minimumDownloads: 0,
                sort: .downloads
            )
        )
        let byLikes = HuggingFaceDiscoveryProjection.project(
            results: results,
            filter: HuggingFaceDiscoveryFilter(
                showOnlySupported: false,
                minimumDownloads: 0,
                sort: .likes
            )
        )

        XCTAssertEqual(byDownloads.map(\.id), ["owner/middle", "owner/alpha", "owner/zeta"])
        XCTAssertEqual(byLikes.map(\.id), ["owner/alpha", "owner/zeta", "owner/middle"])
    }

    func testRecentlyUpdatedHandlesFractionalAndMissingDates() {
        let results = [
            makeResult(id: "owner/no-date", downloads: nil, likes: nil, lastModified: nil, tags: ["mlx"]),
            makeResult(id: "owner/older", downloads: nil, likes: nil, lastModified: "2026-01-01T00:00:00Z", tags: ["mlx"]),
            makeResult(id: "owner/newer", downloads: nil, likes: nil, lastModified: "2026-07-25T10:00:00.123Z", tags: ["mlx"])
        ]

        let projected = HuggingFaceDiscoveryProjection.project(
            results: results,
            filter: HuggingFaceDiscoveryFilter(
                showOnlySupported: false,
                minimumDownloads: 0,
                sort: .recentlyUpdated
            )
        )

        XCTAssertEqual(projected.map(\.id), ["owner/newer", "owner/older", "owner/no-date"])
    }

    func testNameSortAndLocalizedReasonAreDeterministic() {
        let results = [
            makeResult(id: "Owner/beta", downloads: 10, likes: 1, tags: []),
            makeResult(id: "owner/Alpha", downloads: 20, likes: 2, tags: ["mlx"])
        ]

        let projected = HuggingFaceDiscoveryProjection.project(
            results: results,
            filter: HuggingFaceDiscoveryFilter(
                showOnlySupported: false,
                minimumDownloads: 0,
                sort: .name
            )
        )

        XCTAssertEqual(projected.map(\.id), ["owner/Alpha", "Owner/beta"])
        XCTAssertTrue(projected[0].discoveryReason(language: .english).contains("MLX tag verified"))
        XCTAssertTrue(projected[0].discoveryReason(language: .japanese).contains("MLXタグ確認済み"))
    }

    private func makeResult(
        id: String,
        downloads: Int?,
        likes: Int?,
        lastModified: String? = nil,
        tags: [String]
    ) -> HuggingFaceSearchResult {
        HuggingFaceSearchResult(
            id: id,
            downloads: downloads,
            likes: likes,
            lastModified: lastModified,
            tags: tags
        )
    }
}
