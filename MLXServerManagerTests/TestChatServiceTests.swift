import XCTest
@testable import MLXServerManager

final class TestChatServiceTests: XCTestCase {
    override func tearDown() {
        MockTestChatURLProtocol.response = nil
        MockTestChatURLProtocol.requests = []
        super.tearDown()
    }

    func testSendBuildsExpectedRequestAndReturnsAssistantContent() async throws {
        MockTestChatURLProtocol.response = .init(
            statusCode: 200,
            body: #"{"choices":[{"message":{"content":"  pong  "}}]}"#
        )
        let service = TestChatService(session: makeSession())

        let result = try await service.send(
            baseURL: "http://127.0.0.1:8000/v1/",
            modelID: "local/model",
            prompt: "ping"
        )

        XCTAssertEqual(result.responseText, "pong")
        XCTAssertNil(result.apiErrorMessage)
        XCTAssertEqual(result.statusCode, 200)
        XCTAssertEqual(MockTestChatURLProtocol.requests.count, 1)

        let request = try XCTUnwrap(MockTestChatURLProtocol.requests.first)
        XCTAssertEqual(request.url?.absoluteString, "http://127.0.0.1:8000/v1/chat/completions")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")

        let body = try XCTUnwrap(request.httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["model"] as? String, "local/model")
        XCTAssertEqual(json["stream"] as? Bool, false)
        XCTAssertEqual(json["max_tokens"] as? Int, 1_024)
        XCTAssertEqual(json["temperature"] as? Double, 0.7)
        XCTAssertEqual(json["stop"] as? [String], ["USER:", "ASSISTANT:"])
        let messages = try XCTUnwrap(json["messages"] as? [[String: String]])
        XCTAssertEqual(messages, [["role": "user", "content": "ping"]])
    }

    func testSendPreservesAPIErrorForViewModelHandling() async throws {
        MockTestChatURLProtocol.response = .init(
            statusCode: 400,
            body: #"{"error":{"message":" invalid model "}}"#
        )
        let service = TestChatService(session: makeSession())

        let result = try await service.send(
            baseURL: "http://127.0.0.1:8000/v1",
            modelID: "missing/model",
            prompt: "ping"
        )

        XCTAssertEqual(result.statusCode, 400)
        XCTAssertEqual(result.apiErrorMessage, "invalid model")
        XCTAssertTrue(result.responseText.contains("invalid model"))
    }

    func testSendFallsBackToReadableJSONWhenContentIsAbsent() async throws {
        MockTestChatURLProtocol.response = .init(
            statusCode: 200,
            body: #"{"object":"chat.completion","choices":[]}"#
        )
        let service = TestChatService(session: makeSession())

        let result = try await service.send(
            baseURL: "http://127.0.0.1:8000/v1",
            modelID: "local/model",
            prompt: "ping"
        )

        XCTAssertTrue(result.responseText.contains("chat.completion"))
        XCTAssertTrue(result.responseText.contains("choices"))
    }

    func testChatCompletionsURLRejectsMalformedBaseURL() {
        XCTAssertNil(TestChatService.chatCompletionsURL(from: "http://["))
    }

    private func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockTestChatURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}

private final class MockTestChatURLProtocol: URLProtocol {
    struct Response {
        let statusCode: Int
        let body: String
    }

    nonisolated(unsafe) static var response: Response?
    nonisolated(unsafe) static var requests: [URLRequest] = []

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        var capturedRequest = request
        if capturedRequest.httpBody == nil,
           let bodyStream = capturedRequest.httpBodyStream {
            capturedRequest.httpBody = Self.readAllData(from: bodyStream)
        }
        Self.requests.append(capturedRequest)
        guard let response = Self.response else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        let httpResponse = HTTPURLResponse(
            url: request.url!,
            statusCode: response.statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(response.body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    private static func readAllData(from stream: InputStream) -> Data {
        stream.open()
        defer { stream.close() }

        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4_096)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            guard count > 0 else { break }
            data.append(buffer, count: count)
        }
        return data
    }
}
