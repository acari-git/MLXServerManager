import Foundation

enum ReadyCheckResult: Equatable {
    case ready(url: URL, statusCode: Int)
    case notReady(url: URL, statusCode: Int)
    case invalidInput(message: String)
    case failed(url: URL?, message: String)
    case timedOut(url: URL)
}

struct ReadyChecker {
    let timeout: TimeInterval
    private let session: URLSession

    init(timeout: TimeInterval = 3, session: URLSession? = nil) {
        self.timeout = timeout
        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = timeout
            configuration.timeoutIntervalForResource = timeout
            self.session = URLSession(configuration: configuration)
        }
    }

    func check(
        host: String,
        port: Int,
        expectedModelID: String? = nil
    ) async -> ReadyCheckResult {
        guard !host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .invalidInput(message: "Host is empty.")
        }

        guard (1...65535).contains(port) else {
            return .invalidInput(message: "Port must be between 1 and 65535.")
        }

        guard let url = modelsURL(host: host, port: port) else {
            return .invalidInput(message: "Could not build /v1/models URL.")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = timeout

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return .failed(url: url, message: "Response was not HTTP.")
            }

            guard httpResponse.statusCode == 200 else {
                return .notReady(url: url, statusCode: httpResponse.statusCode)
            }

            guard let payload = try? JSONDecoder().decode(OpenAIModelsResponse.self, from: data) else {
                return .failed(url: url, message: "HTTP 200 response was not a valid OpenAI-compatible /v1/models payload.")
            }

            let modelIDs = payload.data
                .map { $0.id.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            guard !modelIDs.isEmpty else {
                return .notReady(url: url, statusCode: httpResponse.statusCode)
            }

            if let expectedModelID = expectedModelID?.trimmingCharacters(in: .whitespacesAndNewlines),
               !expectedModelID.isEmpty,
               !modelIDs.contains(where: { Self.modelIdentifier($0, matches: expectedModelID) }) {
                return .failed(
                    url: url,
                    message: "The endpoint is ready, but the expected model is not present in /v1/models."
                )
            }

            return .ready(url: url, statusCode: httpResponse.statusCode)
        } catch {
            if let urlError = error as? URLError, urlError.code == .timedOut {
                return .timedOut(url: url)
            }

            return .failed(url: url, message: error.localizedDescription)
        }
    }

    nonisolated private static func modelIdentifier(_ actual: String, matches expected: String) -> Bool {
        if actual == expected {
            return true
        }

        let actualName = actual.split(separator: "/").last.map(String.init)
        let expectedName = expected.split(separator: "/").last.map(String.init)
        return actualName != nil && actualName == expectedName
    }

    private func modelsURL(host: String, port: Int) -> URL? {
        var components = URLComponents()
        components.scheme = "http"
        components.host = host
        components.port = port
        components.path = "/v1/models"
        return components.url
    }
}

private struct OpenAIModelsResponse: Decodable {
    struct Model: Decodable {
        let id: String
    }

    let data: [Model]
}
