import Foundation
import XCTest
@testable import MLXServerManager

@MainActor
final class HuggingFaceRepositoryFileServiceTests: XCTestCase {
    override func tearDown() {
        MockHuggingFaceRepositoryURLProtocol.requestHandler = nil
        MockHuggingFaceRepositoryURLProtocol.requests = []
        super.tearDown()
    }

    func testLinkParserFindsNextRelationAmongMultipleLinks() throws {
        let baseURL = try XCTUnwrap(URL(string: "https://huggingface.co/api/models/owner/model/tree/main?recursive=true"))
        let header = "<https://huggingface.co/previous>; rel=\"prev\", <https://huggingface.co/next?cursor=abc>; rel=\"next\""

        XCTAssertEqual(
            HuggingFacePaginationLinkParser.nextURL(from: header, relativeTo: baseURL)?.absoluteString,
            "https://huggingface.co/next?cursor=abc"
        )
    }

    func testFetchFilesFollowsPaginationDeduplicatesAndPreservesAuthorization() async throws {
        let session = makeSession()
        let service = HuggingFaceRepositoryFileService(session: session)
        let nextURL = "https://huggingface.co/api/models/owner/model/tree/main?recursive=true&cursor=abc"

        MockHuggingFaceRepositoryURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer hf_private")
            if request.url?.absoluteString == nextURL {
                return .init(
                    statusCode: 200,
                    headers: ["Content-Type": "application/json"],
                    body: #"[{"type":"file","path":"weights.safetensors","size":20},{"type":"file","path":"tokenizer.json","size":4}]"#
                )
            }
            return .init(
                statusCode: 200,
                headers: [
                    "Content-Type": "application/json",
                    "Link": "<\(nextURL)>; rel=\"next\""
                ],
                body: #"[{"type":"file","path":"config.json","size":3},{"type":"file","path":"weights.safetensors","size":10},{"type":"directory","path":"nested","size":null}]"#
            )
        }

        let files = try await service.fetchFiles(
            repositoryID: "owner/model",
            revision: "main",
            token: "hf_private"
        )

        XCTAssertEqual(files.map(\.path), ["config.json", "tokenizer.json", "weights.safetensors"])
        XCTAssertEqual(files.first(where: { $0.path == "weights.safetensors" })?.size, 20)
        XCTAssertEqual(MockHuggingFaceRepositoryURLProtocol.requests.count, 2)
    }

    func testFetchFilesRejectsPaginationToDifferentHostBeforeSendingToken() async throws {
        let session = makeSession()
        let service = HuggingFaceRepositoryFileService(session: session)

        MockHuggingFaceRepositoryURLProtocol.requestHandler = { _ in
            .init(
                statusCode: 200,
                headers: [
                    "Content-Type": "application/json",
                    "Link": "<https://example.invalid/next?cursor=abc>; rel=\"next\""
                ],
                body: "[]"
            )
        }

        do {
            _ = try await service.fetchFiles(
                repositoryID: "owner/model",
                revision: "main",
                token: "hf_private"
            )
            XCTFail("Expected cross-host pagination to be rejected")
        } catch let error as HuggingFaceRepositoryFileServiceError {
            guard case .invalidPaginationURL = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }

        XCTAssertEqual(MockHuggingFaceRepositoryURLProtocol.requests.count, 1)
    }

    func testFetchFilesDetectsPaginationLoop() async throws {
        let session = makeSession()
        let service = HuggingFaceRepositoryFileService(session: session)

        MockHuggingFaceRepositoryURLProtocol.requestHandler = { request in
            let currentURL = request.url?.absoluteString ?? ""
            return .init(
                statusCode: 200,
                headers: [
                    "Content-Type": "application/json",
                    "Link": "<\(currentURL)>; rel=\"next\""
                ],
                body: "[]"
            )
        }

        do {
            _ = try await service.fetchFiles(
                repositoryID: "owner/model",
                revision: "main",
                token: nil
            )
            XCTFail("Expected pagination loop to fail")
        } catch let error as HuggingFaceRepositoryFileServiceError {
            guard case .paginationLoop = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }

        XCTAssertEqual(MockHuggingFaceRepositoryURLProtocol.requests.count, 1)
    }

    private func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockHuggingFaceRepositoryURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}

private final class MockHuggingFaceRepositoryURLProtocol: URLProtocol {
    struct Response {
        let statusCode: Int
        let headers: [String: String]
        let body: String
    }

    nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> Response)?
    nonisolated(unsafe) static var requests: [URLRequest] = []

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.requests.append(request)
        do {
            guard let handler = Self.requestHandler else {
                throw URLError(.badServerResponse)
            }
            let response = try handler(request)
            let httpResponse = HTTPURLResponse(
                url: request.url!,
                statusCode: response.statusCode,
                httpVersion: "HTTP/1.1",
                headerFields: response.headers
            )!
            client?.urlProtocol(self, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data(response.body.utf8))
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
