import XCTest
@testable import MLXServerManager

final class KVCacheSafeModeTests: XCTestCase {
    private let constrainedEnvironment = KVCacheEnvironment(
        totalMemoryGigabytes: 64,
        availableMemoryGigabytes: 20,
        modelStorageGigabytes: 19,
        isModelLoaded: true
    )

    func testMissingLimitsRemainAtServerDefaults() {
        let result = KVCacheSafeMode.apply(
            options: nil,
            environment: constrainedEnvironment,
            backend: .mlxLM
        )

        XCTAssertFalse(result.didAdjust)
        XCTAssertFalse(result.adjustedEntryLimit)
        XCTAssertFalse(result.adjustedByteLimit)
        XCTAssertNil(result.advancedLaunchOptions)
    }

    func testRapidMLXMissingLimitsAlsoRemainAtServerDefaults() {
        let result = KVCacheSafeMode.apply(
            options: nil,
            environment: constrainedEnvironment,
            backend: .rapidMLX
        )

        XCTAssertFalse(result.didAdjust)
        XCTAssertNil(result.advancedLaunchOptions)
    }

    func testOversizedLimitsAreCappedWithoutChangingOtherOptions() {
        var options = AdvancedLaunchOptions.empty
        options.defaultTemperature = "0.4"
        options.promptCacheSize = "999"
        options.promptCacheBytes = String(16 * 1_073_741_824 as UInt64)

        let result = KVCacheSafeMode.apply(
            options: options,
            environment: constrainedEnvironment,
            backend: .mlxLM
        )

        XCTAssertTrue(result.adjustedEntryLimit)
        XCTAssertTrue(result.adjustedByteLimit)
        XCTAssertEqual(result.advancedLaunchOptions?.defaultTemperature, "0.4")
        XCTAssertEqual(
            result.advancedLaunchOptions?.promptCacheSize,
            String(result.recommendation.entryLimit)
        )
        XCTAssertEqual(
            result.advancedLaunchOptions?.promptCacheBytes,
            String(result.recommendation.byteLimit)
        )
    }

    func testConservativeUserLimitsRemainUnchanged() {
        var options = AdvancedLaunchOptions.empty
        options.promptCacheSize = "2"
        options.promptCacheBytes = String(256 * 1_048_576 as UInt64)

        let result = KVCacheSafeMode.apply(
            options: options,
            environment: constrainedEnvironment,
            backend: .mlxLM
        )

        XCTAssertFalse(result.didAdjust)
        XCTAssertEqual(result.advancedLaunchOptions, options.normalized())
    }

    func testInvalidConfiguredValuesRemainVisibleForValidator() {
        var options = AdvancedLaunchOptions.empty
        options.promptCacheSize = "invalid"
        options.promptCacheBytes = "invalid"

        let result = KVCacheSafeMode.apply(
            options: options,
            environment: constrainedEnvironment,
            backend: .mlxLM
        )

        XCTAssertFalse(result.didAdjust)
        XCTAssertEqual(result.advancedLaunchOptions?.promptCacheSize, "invalid")
        XCTAssertEqual(result.advancedLaunchOptions?.promptCacheBytes, "invalid")
    }

    func testAdjustmentTextIsLocalizedAndStatesProfileIsUnchanged() {
        var options = AdvancedLaunchOptions.empty
        options.promptCacheSize = "999"
        options.promptCacheBytes = String(16 * 1_073_741_824 as UInt64)
        let result = KVCacheSafeMode.apply(
            options: options,
            environment: constrainedEnvironment,
            backend: .mlxLM
        )

        XCTAssertTrue(result.didAdjust)
        XCTAssertTrue(result.actionText(language: .english).contains("profile was not changed"))
        XCTAssertTrue(result.actionText(language: .japanese).contains("プロファイルは変更していません"))
    }
}
