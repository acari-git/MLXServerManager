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

    init(timeout: TimeInterval = 3) {
        self.timeout = timeout
    }

    func check(host: String, port: Int) async -> ReadyCheckResult {
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
            let (_, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return .failed(url: url, message: "Response was not HTTP.")
            }

            if httpResponse.statusCode == 200 {
                return .ready(url: url, statusCode: httpResponse.statusCode)
            }

            return .notReady(url: url, statusCode: httpResponse.statusCode)
        } catch {
            if let urlError = error as? URLError, urlError.code == .timedOut {
                return .timedOut(url: url)
            }

            return .failed(url: url, message: error.localizedDescription)
        }
    }

    private var session: URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout
        return URLSession(configuration: configuration)
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

