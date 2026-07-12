import Foundation

protocol HuggingFaceRepositoryFileListing {
    func fetchFiles(repositoryID: String, revision: String, token: String?) async throws -> [HuggingFaceDownloadPreviewFile]
}

enum HuggingFaceRepositoryFileServiceError: LocalizedError {
    case invalidURL
    case invalidResponse
    case invalidPaginationURL
    case paginationLoop
    case tooManyPages
    case apiFailure(Int, String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Could not build Hugging Face API URL."
        case .invalidResponse:
            return "Unexpected Hugging Face API response."
        case .invalidPaginationURL:
            return "Hugging Face API returned an invalid pagination URL."
        case .paginationLoop:
            return "Hugging Face API returned a pagination loop."
        case .tooManyPages:
            return "Hugging Face API returned too many pagination pages."
        case let .apiFailure(status, message):
            return "Hugging Face API error \(status): \(message)"
        }
    }
}

final class HuggingFaceRepositoryFileService: HuggingFaceRepositoryFileListing {
    private let session: URLSession
    private let maximumPageCount: Int

    init(
        session: URLSession = .shared,
        maximumPageCount: Int = 1_000
    ) {
        self.session = session
        self.maximumPageCount = max(maximumPageCount, 1)
    }

    func fetchFiles(
        repositoryID: String,
        revision: String,
        token: String?
    ) async throws -> [HuggingFaceDownloadPreviewFile] {
        let initialURL = try repositoryTreeURL(repositoryID: repositoryID, revision: revision)
        var nextURL: URL? = initialURL
        var visitedURLs: Set<URL> = []
        var filesByPath: [String: HuggingFaceDownloadPreviewFile] = [:]
        var pageCount = 0

        while let pageURL = nextURL {
            try Task.checkCancellation()

            guard pageCount < maximumPageCount else {
                throw HuggingFaceRepositoryFileServiceError.tooManyPages
            }
            guard visitedURLs.insert(pageURL).inserted else {
                throw HuggingFaceRepositoryFileServiceError.paginationLoop
            }
            pageCount += 1

            let page = try await fetchPage(url: pageURL, token: token)
            for entry in page.entries where entry.type == "file" && !entry.path.isEmpty {
                filesByPath[entry.path] = HuggingFaceDownloadPreviewFile(path: entry.path, size: entry.size)
            }

            guard let candidate = page.nextURL else {
                nextURL = nil
                continue
            }
            guard candidate.scheme?.lowercased() == initialURL.scheme?.lowercased(),
                  candidate.host?.lowercased() == initialURL.host?.lowercased() else {
                throw HuggingFaceRepositoryFileServiceError.invalidPaginationURL
            }
            nextURL = candidate
        }

        return filesByPath.values.sorted {
            $0.path.localizedStandardCompare($1.path) == .orderedAscending
        }
    }

    private func repositoryTreeURL(repositoryID: String, revision: String) throws -> URL {
        let encodedRepositoryID = repositoryID.split(separator: "/").map { part in
            String(part).addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? String(part)
        }.joined(separator: "/")
        let encodedRevision = revision.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? revision
        var components = URLComponents()
        components.scheme = "https"
        components.host = "huggingface.co"
        components.percentEncodedPath = "/api/models/\(encodedRepositoryID)/tree/\(encodedRevision)"
        components.queryItems = [URLQueryItem(name: "recursive", value: "true")]
        guard let url = components.url else {
            throw HuggingFaceRepositoryFileServiceError.invalidURL
        }
        return url
    }

    private func fetchPage(url: URL, token: String?) async throws -> HuggingFaceRepositoryTreePage {
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
            throw HuggingFaceRepositoryFileServiceError.apiFailure(
                httpResponse.statusCode,
                String(responseText.prefix(240))
            )
        }

        let entries = try JSONDecoder().decode([HuggingFaceRepositoryTreeEntry].self, from: data)
        return HuggingFaceRepositoryTreePage(
            entries: entries,
            nextURL: HuggingFacePaginationLinkParser.nextURL(from: httpResponse)
        )
    }
}

struct HuggingFacePaginationLinkParser {
    nonisolated static func nextURL(from response: HTTPURLResponse) -> URL? {
        guard let linkHeader = response.value(forHTTPHeaderField: "Link"),
              let baseURL = response.url else {
            return nil
        }
        return nextURL(from: linkHeader, relativeTo: baseURL)
    }

    nonisolated static func nextURL(from linkHeader: String, relativeTo baseURL: URL) -> URL? {
        let pattern = #"<([^>]+)>\s*;\s*rel\s*=\s*\"?([^\";,]+)\"?"#
        guard let expression = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }

        let range = NSRange(linkHeader.startIndex..<linkHeader.endIndex, in: linkHeader)
        for match in expression.matches(in: linkHeader, range: range) {
            guard match.numberOfRanges >= 3,
                  let urlRange = Range(match.range(at: 1), in: linkHeader),
                  let relationRange = Range(match.range(at: 2), in: linkHeader) else {
                continue
            }

            let relation = linkHeader[relationRange]
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            guard relation.split(whereSeparator: \Character.isWhitespace).contains("next") else {
                continue
            }

            let value = String(linkHeader[urlRange])
            return URL(string: value, relativeTo: baseURL)?.absoluteURL
        }
        return nil
    }
}

private struct HuggingFaceRepositoryTreePage {
    let entries: [HuggingFaceRepositoryTreeEntry]
    let nextURL: URL?
}

private struct HuggingFaceRepositoryTreeEntry: Decodable {
    let type: String
    let path: String
    let size: Int64?
}
