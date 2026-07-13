import XCTest
@testable import MLXServerManager

final class KVCacheAdvisorTests: XCTestCase {
    func testRecommendationUsesModelAndMemoryHeadroom() {
        let environment = KVCacheEnvironment(
            totalMemoryGigabytes: 64,
            availableMemoryGigabytes: 40,
            modelStorageGigabytes: 19,
            isModelLoaded: false
        )

        let recommendation = KVCacheAdvisor.recommendedConfiguration(environment: environment)

        XCTAssertEqual(recommendation.entryLimit, 8)
        XCTAssertEqual(recommendation.byteLimit, 2 * 1_073_741_824)
        XCTAssertEqual(recommendation.projectedHeadroomGigabytes, 8.55, accuracy: 0.001)
    }

    func testLoadedModelDoesNotSubtractStorageEstimateAgain() {
        let environment = KVCacheEnvironment(
            totalMemoryGigabytes: 64,
            availableMemoryGigabytes: 20,
            modelStorageGigabytes: 19,
            isModelLoaded: true
        )

        let recommendation = KVCacheAdvisor.recommendedConfiguration(environment: environment)

        XCTAssertEqual(recommendation.byteLimit, 2 * 1_073_741_824)
        XCTAssertEqual(recommendation.projectedHeadroomGigabytes, 10.4, accuracy: 0.001)
    }

    func testServerDefaultsWarnWhenHeadroomIsConstrained() {
        let environment = KVCacheEnvironment(
            totalMemoryGigabytes: 32,
            availableMemoryGigabytes: 8,
            modelStorageGigabytes: 14,
            isModelLoaded: true
        )

        let assessment = KVCacheAdvisor.assess(options: .empty, environment: environment)

        XCTAssertEqual(assessment.level, .warning)
        XCTAssertTrue(assessment.usesDefaultEntryLimit)
        XCTAssertTrue(assessment.usesUnlimitedByteDefault)
    }

    func testRecommendedValuesProduceHealthyAssessment() {
        let environment = KVCacheEnvironment(
            totalMemoryGigabytes: 64,
            availableMemoryGigabytes: 40,
            modelStorageGigabytes: 19,
            isModelLoaded: false
        )
        let recommendation = KVCacheAdvisor.recommendedConfiguration(environment: environment)
        var options = AdvancedLaunchOptions.empty
        options.promptCacheSize = String(recommendation.entryLimit)
        options.promptCacheBytes = String(recommendation.byteLimit)

        let assessment = KVCacheAdvisor.assess(options: options, environment: environment)

        XCTAssertEqual(assessment.level, .healthy)
    }

    func testRawPromptCacheArgumentsAreReportedAsOverrideRisk() {
        let environment = KVCacheEnvironment(
            totalMemoryGigabytes: 64,
            availableMemoryGigabytes: 40,
            modelStorageGigabytes: 19,
            isModelLoaded: false
        )
        var options = AdvancedLaunchOptions.empty
        options.promptCacheSize = "8"
        options.promptCacheBytes = String(2 * 1_073_741_824)
        options.rawExtraArgs = "--prompt-cache-size 20"

        let assessment = KVCacheAdvisor.assess(options: options, environment: environment)

        XCTAssertEqual(assessment.level, .warning)
        XCTAssertTrue(assessment.hasRawArgumentOverride)
    }

    func testRapidMLXAutomaticMemoryAwareCacheIsDiagnosedWithoutClaimingUnlimitedDefault() {
        let environment = KVCacheEnvironment(
            totalMemoryGigabytes: 64,
            availableMemoryGigabytes: 20,
            modelStorageGigabytes: 19,
            isModelLoaded: true
        )

        let assessment = KVCacheAdvisor.assess(
            options: .empty,
            environment: environment,
            backend: .rapidMLX
        )

        XCTAssertEqual(assessment.backend, .rapidMLX)
        XCTAssertEqual(assessment.level, .attention)
        XCTAssertEqual(assessment.effectiveEntryLimit, 100)
        XCTAssertFalse(assessment.usesUnlimitedByteDefault)
        XCTAssertTrue(assessment.detail(language: .english).contains("memory-aware"))
    }

    func testRapidMLXRawCacheArgumentsAreReportedAsOverrideRisk() {
        let environment = KVCacheEnvironment(
            totalMemoryGigabytes: 64,
            availableMemoryGigabytes: 20,
            modelStorageGigabytes: 19,
            isModelLoaded: true
        )
        var options = AdvancedLaunchOptions.empty
        options.rawExtraArgs = "--cache-memory-percent 0.4"

        let assessment = KVCacheAdvisor.assess(
            options: options,
            environment: environment,
            backend: .rapidMLX
        )

        XCTAssertEqual(assessment.level, .warning)
        XCTAssertTrue(assessment.hasRawArgumentOverride)
    }
}
