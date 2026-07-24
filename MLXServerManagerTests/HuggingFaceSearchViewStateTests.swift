import XCTest
@testable import MLXServerManager

final class HuggingFaceSearchViewStateTests: XCTestCase {
    func testSearchLifecyclePublishesResultsSelectionAndMessageTogether() {
        let selected = makeResult(id: "owner/model", downloads: 100)
        let other = makeResult(id: "owner/other", downloads: 10)
        var state = HuggingFaceSearchViewState.initial(message: "Ready")

        state.setQuery("owner/model")
        state.beginSearch(message: "Searching")

        XCTAssertEqual(state.query, "owner/model")
        XCTAssertEqual(state.message, "Searching")
        XCTAssertTrue(state.isSearching)
        XCTAssertTrue(state.results.isEmpty)
        XCTAssertNil(state.selectedResult)

        state.completeSearch(
            results: [selected, other],
            selectedResult: selected,
            message: "Selected"
        )

        XCTAssertEqual(state.results, [selected, other])
        XCTAssertEqual(state.selectedResult, selected)
        XCTAssertEqual(state.message, "Selected")
        XCTAssertFalse(state.isSearching)
    }

    func testEmptyQueryResetClearsPreviousSearchState() {
        let result = makeResult(id: "owner/model")
        var state = HuggingFaceSearchViewState.initial(message: "Ready")
        state.completeSearch(results: [result], selectedResult: result, message: "Selected")
        state.beginSearch(message: "Searching")

        state.resetForEmptyQuery(message: "Enter a search term")

        XCTAssertTrue(state.results.isEmpty)
        XCTAssertNil(state.selectedResult)
        XCTAssertFalse(state.isSearching)
        XCTAssertEqual(state.message, "Enter a search term")
    }

    func testFailureClearsResultsAndEndsSearch() {
        let result = makeResult(id: "owner/model")
        var state = HuggingFaceSearchViewState.initial(message: "Ready")
        state.completeSearch(results: [result], selectedResult: result, message: "Selected")
        state.beginSearch(message: "Searching")

        state.failSearch(message: "Network unavailable")

        XCTAssertTrue(state.results.isEmpty)
        XCTAssertNil(state.selectedResult)
        XCTAssertFalse(state.isSearching)
        XCTAssertEqual(state.message, "Network unavailable")
    }

    func testManualSelectionPreservesResultListAndSearchFlag() {
        let first = makeResult(id: "owner/first")
        let second = makeResult(id: "owner/second")
        var state = HuggingFaceSearchViewState.initial(message: "Ready")
        state.completeSearch(results: [first, second], selectedResult: first, message: "Selected first")

        state.selectResult(second, message: "Selected second")

        XCTAssertEqual(state.results, [first, second])
        XCTAssertEqual(state.selectedResult, second)
        XCTAssertEqual(state.message, "Selected second")
        XCTAssertFalse(state.isSearching)
    }

    private func makeResult(
        id: String,
        downloads: Int = 1
    ) -> HuggingFaceSearchResult {
        HuggingFaceSearchResult(
            id: id,
            downloads: downloads,
            likes: 1,
            lastModified: nil,
            tags: ["mlx"]
        )
    }
}
