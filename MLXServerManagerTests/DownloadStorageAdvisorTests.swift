import XCTest
@testable import MLXServerManager

final class DownloadStorageAdvisorTests: XCTestCase {
    func testSufficientCapacityDoesNotBlockDownload() {
        let assessment = assess(
            files: [file(path: "model.safetensors", expected: 1_000)],
            availableCapacity: 2_000
        )

        XCTAssertEqual(assessment.kind, .sufficient)
        XCTAssertEqual(assessment.requirement.knownRemainingBytes, 1_000)
        XCTAssertEqual(assessment.requirement.totalRemainingBytes, 1_000)
        XCTAssertFalse(assessment.blocksDownload)
    }

    func testInsufficientCapacityIsTheOnlyBlockingAssessment() {
        let assessment = assess(
            files: [file(path: "model.safetensors", expected: 2_000)],
            availableCapacity: 1_000
        )

        XCTAssertEqual(assessment.kind, .insufficient)
        XCTAssertTrue(assessment.blocksDownload)
        XCTAssertTrue(assessment.title(language: .english).contains("Not enough"))
        XCTAssertTrue(assessment.title(language: .japanese).contains("不足"))
        XCTAssertTrue(assessment.detail(language: .english).contains("Free at least"))
        XCTAssertTrue(assessment.detail(language: .japanese).contains("空けて"))
    }

    func testPartialExistingFileRequiresOnlyRemainingDifference() {
        let requirement = DownloadStorageAdvisor.requirement(
            for: [file(path: "weights/model.safetensors", expected: 1_000, existing: 400)]
        )

        XCTAssertEqual(requirement.knownRemainingBytes, 600)
        XCTAssertEqual(requirement.totalRemainingBytes, 600)
        XCTAssertFalse(requirement.hasUnknownSizes)
    }

    func testUnknownExpectedSizePreservesPathAndDoesNotBlock() {
        let assessment = assess(
            files: [
                file(path: "config.json", expected: 100),
                file(path: "weights/unknown.safetensors", expected: nil, existing: 50)
            ],
            availableCapacity: 1_000
        )

        XCTAssertEqual(assessment.kind, .requiredUnknown)
        XCTAssertEqual(assessment.requirement.knownRemainingBytes, 100)
        XCTAssertNil(assessment.requirement.totalRemainingBytes)
        XCTAssertEqual(
            assessment.requirement.unknownSizePaths,
            ["weights/unknown.safetensors"]
        )
        XCTAssertTrue(assessment.requirement.hasUnknownSizes)
        XCTAssertFalse(assessment.blocksDownload)
    }

    func testUnknownCapacityIsReportedWithoutBlocking() {
        let assessment = assess(
            files: [file(path: "model.safetensors", expected: 1_000)],
            availableCapacity: nil
        )

        XCTAssertEqual(assessment.kind, .capacityUnknown)
        XCTAssertNil(assessment.availableCapacityBytes)
        XCTAssertFalse(assessment.blocksDownload)
        XCTAssertTrue(assessment.title(language: .english).contains("could not be checked"))
        XCTAssertTrue(assessment.title(language: .japanese).contains("確認できません"))
    }

    func testExistingFileAtOrAboveExpectedSizeRequiresNoAdditionalBytes() {
        let requirement = DownloadStorageAdvisor.requirement(
            for: [
                file(path: "exact.bin", expected: 1_000, existing: 1_000),
                file(path: "oversized.bin", expected: 1_000, existing: 1_500)
            ]
        )

        XCTAssertEqual(requirement.knownRemainingBytes, 0)
        XCTAssertEqual(requirement.totalRemainingBytes, 0)
    }

    func testAssessmentUsesInjectedCapacityProviderForDestination() {
        let destinationURL = URL(fileURLWithPath: "/tmp/models/example", isDirectory: true)
        let provider = RecordingCapacityProvider(capacity: 4_096)

        let assessment = DownloadStorageAdvisor.assess(
            files: [file(path: "model.bin", expected: 2_048)],
            destinationDirectoryURL: destinationURL,
            capacityProvider: provider
        )

        XCTAssertEqual(assessment.kind, .sufficient)
        XCTAssertEqual(provider.requestedURL, destinationURL)
    }

    private func assess(
        files: [DownloadStorageExpectedFile],
        availableCapacity: Int64?
    ) -> DownloadStorageAssessment {
        DownloadStorageAdvisor.assess(
            files: files,
            destinationDirectoryURL: URL(fileURLWithPath: "/tmp/models", isDirectory: true),
            capacityProvider: FixedCapacityProvider(capacity: availableCapacity)
        )
    }

    private func file(
        path: String,
        expected: Int64?,
        existing: Int64? = nil
    ) -> DownloadStorageExpectedFile {
        DownloadStorageExpectedFile(
            path: path,
            expectedSizeBytes: expected,
            existingSizeBytes: existing
        )
    }
}

private struct FixedCapacityProvider: DownloadStorageCapacityProviding {
    let capacity: Int64?

    func availableCapacityForImportantUsage(at destinationDirectoryURL: URL) -> Int64? {
        capacity
    }
}

private final class RecordingCapacityProvider: DownloadStorageCapacityProviding {
    let capacity: Int64?
    private(set) var requestedURL: URL?

    init(capacity: Int64?) {
        self.capacity = capacity
    }

    func availableCapacityForImportantUsage(at destinationDirectoryURL: URL) -> Int64? {
        requestedURL = destinationDirectoryURL
        return capacity
    }
}
