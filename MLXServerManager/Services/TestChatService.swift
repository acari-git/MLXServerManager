import Foundation

nonisolated struct TestChatServiceResult: Equatable, Sendable {
    let responseText: String
    let apiErrorMessage: String?
    let statusCode: Int?
    let durationMilliseconds: Double
}

nonisolated enum TestChatServiceError: Error, Equatable {
    case invalidBaseURL
}

nonisolated struct TestChatService: Sendable {
    typealias SendOperation = @Sendable (
        _ baseURL: String,
        _ modelID: String,
        _ prompt: String
    ) async throws -> TestChatServiceResult

    private let session: URLSession
    private let timeout: TimeInterval
    private let sendOperation: SendOperation?

    init(
        session: URLSession = .shared,
        timeout: TimeInterval = 60
    ) {
        self.session = session
        self.timeout = timeout
        self.sendOperation = nil
    }

    init(sendOperation: @escaping SendOperation) {
        self.session = .shared
        self.timeout = 60
        self.sendOperation = sendOperation
    }

    func send(
        baseURL: String,
        modelID: String,
        prompt: String
    ) async throws -> TestChatServiceResult {
        if let sendOperation {
            return try await sendOperation(baseURL, modelID, prompt)
        }

        guard let url = Self.chatCompletionsURL(from: baseURL) else {
            throw TestChatServiceError.invalidBaseURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            TestChatRequestPayload(
                model: modelID,
                messages: [TestChatMessagePayload(role: "user", content: prompt)],
                stream: false,
                maxTokens: 1_024,
                temperature: 0.7,
                stop: ["USER:", "ASSISTANT:"]
            )
        )

        let startedAt = Date()
        let (data, response) = try await session.data(for: request)
        let durationMilliseconds = Date().timeIntervalSince(startedAt) * 1_000
        let statusCode = (response as? HTTPURLResponse)?.statusCode
        let decoded = try? JSONDecoder().decode(TestChatResponsePayload.self, from: data)
        let apiErrorMessage = decoded?.error?.message?.trimmingCharacters(in: .whitespacesAndNewlines)
        let content = decoded?.choices?.first?.message?.content?.trimmingCharacters(in: .whitespacesAndNewlines)
        let responseText: String
        if let content, !content.isEmpty {
            responseText = content
        } else {
            responseText = Self.fallbackResponseText(from: data)
        }

        return TestChatServiceResult(
            responseText: responseText,
            apiErrorMessage: apiErrorMessage?.isEmpty == false ? apiErrorMessage : nil,
            statusCode: statusCode,
            durationMilliseconds: durationMilliseconds
        )
    }

    static func chatCompletionsURL(from baseURL: String) -> URL? {
        let trimmed = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return URL(string: "\(trimmed)/chat/completions")
    }

    private static func fallbackResponseText(from data: Data) -> String {
        if let object = try? JSONSerialization.jsonObject(with: data),
           let prettyData = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted]),
           let text = String(data: prettyData, encoding: .utf8) {
            return text
        }
        return String(data: data, encoding: .utf8) ?? ""
    }
}

nonisolated private struct TestChatMessagePayload: Codable {
    let role: String
    let content: String
}

nonisolated private struct TestChatRequestPayload: Encodable {
    let model: String
    let messages: [TestChatMessagePayload]
    let stream: Bool
    let maxTokens: Int
    let temperature: Double
    let stop: [String]

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case stream
        case maxTokens = "max_tokens"
        case temperature
        case stop
    }
}

nonisolated private struct TestChatResponsePayload: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let content: String?
        }

        let message: Message?
    }

    struct ErrorPayload: Decodable {
        let message: String?
    }

    let choices: [Choice]?
    let error: ErrorPayload?
}
