import Foundation

protocol HuggingFaceRepositoryFileListing {
    func fetchFiles(repositoryID: String, revision: String, token: String?) async throws -> [HuggingFaceDownloadPreviewFile]
}

enum HuggingFaceRepositoryFileServiceError: LocalizedError {
    case invalidURL
    case invalidResponse
    case apiFailure(Int, String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Could not build Hugging Face API URL."
        case .invalidResponse: return "Unexpected Hugging Face API response."
        case let .apiFailure(status, message): return "Hugging Face API error \(status): \(message)"
        }
    }
}

final class HuggingFaceRepositoryFileService: HuggingFaceRepositoryFileListing {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchFiles(repositoryID: String, revision: String, token: String?) async throws -> [HuggingFaceDownloadPreviewFile] {
        let encodedRepositoryID = repositoryID.split(separator: "/").map { part in
            String(part).addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? String(part)
        }.joined(separator: "/")
        let encodedRevision = revision.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? revision
        var components = URLComponents()
        components.scheme = "https"
        components.host = "huggingface.co"
        components.percentEncodedPath = "/api/models/\(encodedRepositoryID)/tree/\(encodedRevision)"
        components.queryItems = [URLQueryItem(name: "recursive", value: "true")]
        guard let url = components.url else { throw HuggingFaceRepositoryFileServiceError.invalidURL }

        var request = URLRequest(url: url)
        if let token, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw HuggingFaceRepositoryFileServiceError.invalidResponse
        }
        guard httpResponse.statusCode == 200 else {
            let responseText = String(data: data, encoding: .utf8) ?? "Request failed"
            throw HuggingFaceRepositoryFileServiceError.apiFailure(httpResponse.statusCode, String(responseText.prefix(240)))
        }

        let entries = try JSONDecoder().decode([HuggingFaceRepositoryTreeEntry].self, from: data)
        return entries
            .filter { $0.type == "file" && !$0.path.isEmpty }
            .map { HuggingFaceDownloadPreviewFile(path: $0.path, size: $0.size) }
            .sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
    }
}

private struct HuggingFaceRepositoryTreeEntry: Decodable {
    let type: String
    let path: String
    let size: Int64?
}
