import Foundation

nonisolated struct HuggingFaceSearchViewState: Equatable, Sendable {
    private(set) var query: String
    private(set) var message: String
    private(set) var results: [HuggingFaceSearchResult]
    private(set) var selectedResult: HuggingFaceSearchResult?
    private(set) var isSearching: Bool

    static func initial(message: String) -> HuggingFaceSearchViewState {
        HuggingFaceSearchViewState(
            query: "",
            message: message,
            results: [],
            selectedResult: nil,
            isSearching: false
        )
    }

    mutating func setQuery(_ query: String) {
        self.query = query
    }

    mutating func setMessage(_ message: String) {
        self.message = message
    }

    mutating func beginSearch(message: String) {
        self.message = message
        isSearching = true
    }

    mutating func finishSearch() {
        isSearching = false
    }

    mutating func resetForEmptyQuery(message: String) {
        results = []
        selectedResult = nil
        isSearching = false
        self.message = message
    }

    mutating func completeSearch(
        results: [HuggingFaceSearchResult],
        selectedResult: HuggingFaceSearchResult?,
        message: String
    ) {
        self.results = results
        self.selectedResult = selectedResult
        self.message = message
        isSearching = false
    }

    mutating func failSearch(message: String) {
        results = []
        selectedResult = nil
        self.message = message
        isSearching = false
    }

    mutating func selectResult(
        _ result: HuggingFaceSearchResult,
        message: String
    ) {
        selectedResult = result
        self.message = message
    }
}
