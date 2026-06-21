import Foundation

protocol HuggingFaceModelSearching {
    func search(query: String, limit: Int) async throws -> [HuggingFaceSearchResult]
}

enum HuggingFaceSearchError: LocalizedError, Equatable {
    case emptyQuery
    case invalidURL
    case requestFailed(String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .emptyQuery:
            "Enter a search term before searching."
        case .invalidURL:
            "Could not build the Hugging Face search URL."
        case let .requestFailed(message):
            "Hugging Face search failed: \(message)"
        case .invalidResponse:
            "Hugging Face search returned an invalid response."
        }
    }
}

final class HuggingFaceSearchService: HuggingFaceModelSearching {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func search(query: String, limit: Int = 10) async throws -> [HuggingFaceSearchResult] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            throw HuggingFaceSearchError.emptyQuery
        }

        var components = URLComponents(string: "https://huggingface.co/api/models")
        components?.queryItems = [
            URLQueryItem(name: "search", value: trimmedQuery),
            URLQueryItem(name: "limit", value: String(max(1, min(limit, 20))))
        ]

        guard let url = components?.url else {
            throw HuggingFaceSearchError.invalidURL
        }

        do {
            let (data, response) = try await session.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode) else {
                throw HuggingFaceSearchError.invalidResponse
            }
            let items = try JSONDecoder().decode([HuggingFaceSearchResponseItem].self, from: data)
            return items
                .map { $0.result() }
                .sorted { lhs, rhs in
                    lhs.qualityRank == rhs.qualityRank ? lhs.id < rhs.id : lhs.qualityRank > rhs.qualityRank
                }
        } catch let error as HuggingFaceSearchError {
            throw error
        } catch {
            throw HuggingFaceSearchError.requestFailed(error.localizedDescription)
        }
    }
}
