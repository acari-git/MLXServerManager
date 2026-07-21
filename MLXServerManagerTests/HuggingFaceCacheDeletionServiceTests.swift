import XCTest
@testable import MLXServerManager

final class HuggingFaceCacheDeletionServiceTests: XCTestCase {
    func testDeleteCacheRemovesDirectoryOffTheCallingActor() async throws {
        let cacheURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: cacheURL, withIntermediateDirectories: true)
        try Data(repeating: 1, count: 16).write(to: cacheURL.appendingPathComponent("blob"))

        let outcome = await HuggingFaceCacheDeletionService().deleteCache(at: cacheURL)

        XCTAssertEqual(outcome, .deleted)
        XCTAssertFalse(FileManager.default.fileExists(atPath: cacheURL.path))
    }

    func testDeleteCacheReportsMissingDirectory() async {
        let cacheURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)

        let outcome = await HuggingFaceCacheDeletionService().deleteCache(at: cacheURL)

        XCTAssertEqual(outcome, .notFound)
    }
}
