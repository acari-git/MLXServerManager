import XCTest
@testable import MLXServerManager

final class ModelProfileTemplateTests: XCTestCase {
    func testBalancedTemplatePreservesProfileIdentityAndUnmanagedOptions() {
        var draft = ModelProfileDraft.newProfile(defaultHost: "127.0.0.1", defaultPort: 9000)
        draft.displayName = "Local Model"
        draft.modelID = "/Models/local-model"
        draft.notes = "Keep this note"
        draft.enableThinking = true
        draft.backend = .mlxLM
        draft.advancedLaunchOptions.defaultTemperature = "0.25"
        draft.advancedLaunchOptions.allowedOrigins = "http://localhost:3000"
        draft.advancedLaunchOptions.chatTemplateArgs = #"{"enable_thinking":true}"#
        draft.advancedLaunchOptions.rawExtraArgs = "--custom-option value"

        let updated = ModelProfileTemplate.balanced.applying(to: draft)

        XCTAssertEqual(updated.displayName, draft.displayName)
        XCTAssertEqual(updated.modelID, draft.modelID)
        XCTAssertEqual(updated.host, draft.host)
        XCTAssertEqual(updated.serverPortText, draft.serverPortText)
        XCTAssertEqual(updated.notes, draft.notes)
        XCTAssertEqual(updated.enableThinking, draft.enableThinking)
        XCTAssertEqual(updated.backend, draft.backend)
        XCTAssertEqual(updated.advancedLaunchOptions.defaultTemperature, "0.25")
        XCTAssertEqual(updated.advancedLaunchOptions.allowedOrigins, "http://localhost:3000")
        XCTAssertEqual(updated.advancedLaunchOptions.chatTemplateArgs, #"{"enable_thinking":true}"#)
        XCTAssertEqual(updated.advancedLaunchOptions.rawExtraArgs, "--custom-option value")
        XCTAssertEqual(updated.advancedLaunchOptions.decodeConcurrency, "1")
        XCTAssertEqual(updated.advancedLaunchOptions.promptConcurrency, "1")
        XCTAssertEqual(updated.advancedLaunchOptions.prefillStepSize, "512")
        XCTAssertEqual(updated.advancedLaunchOptions.promptCacheSize, "2")
    }

    func testMinimalTemplateClearsOnlyManagedPerformanceFields() {
        var draft = ModelProfileDraft.newProfile(defaultHost: "localhost", defaultPort: 8080)
        draft.advancedLaunchOptions.defaultTopP = "0.9"
        draft.advancedLaunchOptions.rawExtraArgs = "--keep-me"
        draft.advancedLaunchOptions.decodeConcurrency = "4"
        draft.advancedLaunchOptions.promptConcurrency = "4"
        draft.advancedLaunchOptions.prefillStepSize = "2048"
        draft.advancedLaunchOptions.promptCacheSize = "8"
        draft.advancedLaunchOptions.promptCacheBytes = "536870912"

        let updated = ModelProfileTemplate.minimal.applying(to: draft)

        XCTAssertEqual(updated.advancedLaunchOptions.defaultTopP, "0.9")
        XCTAssertEqual(updated.advancedLaunchOptions.rawExtraArgs, "--keep-me")
        XCTAssertNil(updated.advancedLaunchOptions.decodeConcurrency)
        XCTAssertNil(updated.advancedLaunchOptions.promptConcurrency)
        XCTAssertNil(updated.advancedLaunchOptions.prefillStepSize)
        XCTAssertNil(updated.advancedLaunchOptions.promptCacheSize)
        XCTAssertNil(updated.advancedLaunchOptions.promptCacheBytes)
    }

    func testMemorySaverIsDeterministicAcrossBackends() {
        for backend in InferenceBackend.allCases {
            var draft = ModelProfileDraft.newProfile(defaultHost: "127.0.0.1", defaultPort: 8080)
            draft.backend = backend

            let updated = ModelProfileTemplate.memorySaver.applying(to: draft)

            XCTAssertEqual(updated.advancedLaunchOptions.decodeConcurrency, "1")
            XCTAssertEqual(updated.advancedLaunchOptions.promptConcurrency, "1")
            XCTAssertEqual(updated.advancedLaunchOptions.prefillStepSize, "256")
            XCTAssertEqual(updated.advancedLaunchOptions.promptCacheSize, "1")
        }
    }

    func testThroughputUsesBackendSpecificConcurrency() {
        var mlxDraft = ModelProfileDraft.newProfile(defaultHost: "127.0.0.1", defaultPort: 8080)
        mlxDraft.backend = .mlxLM
        var rapidDraft = mlxDraft
        rapidDraft.backend = .rapidMLX

        let mlx = ModelProfileTemplate.throughput.applying(to: mlxDraft)
        let rapid = ModelProfileTemplate.throughput.applying(to: rapidDraft)

        XCTAssertEqual(mlx.advancedLaunchOptions.decodeConcurrency, "2")
        XCTAssertEqual(rapid.advancedLaunchOptions.decodeConcurrency, "4")
        XCTAssertEqual(mlx.advancedLaunchOptions.prefillStepSize, "1024")
        XCTAssertEqual(rapid.advancedLaunchOptions.prefillStepSize, "1024")
    }

    func testTemplateTitlesAndDetailsExistInBothLanguages() {
        for template in ModelProfileTemplate.allCases {
            XCTAssertFalse(template.localizedTitle(language: .english).isEmpty)
            XCTAssertFalse(template.localizedTitle(language: .japanese).isEmpty)
            XCTAssertFalse(template.localizedDetail(language: .english).isEmpty)
            XCTAssertFalse(template.localizedDetail(language: .japanese).isEmpty)
        }
    }
}
