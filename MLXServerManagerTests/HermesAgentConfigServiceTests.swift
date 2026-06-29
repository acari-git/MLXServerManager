import XCTest
@testable import MLXServerManager

final class HermesAgentConfigServiceTests: XCTestCase {
    func testApplyUpdatesModelConnectionAndPreservesOtherYaml() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MLXServerManagerTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let configURL = temporaryDirectory.appendingPathComponent("config.yaml")
        let original = """
        model:
          default: old-model
          provider: custom
          base_url: http://127.0.0.1:8000/v1
          api_key: ''
          context_length: 262144
        agent:
          max_turns: 60
        """
        try original.write(to: configURL, atomically: true, encoding: .utf8)

        let service = HermesAgentConfigService(
            fileManager: .default,
            dateProvider: { Date(timeIntervalSince1970: 1_782_000_000) }
        )
        let result = try service.apply(
            connection: HermesAgentConnectionSettings(
                baseURL: "http://127.0.0.1:8080/v1",
                modelID: "mlx-community/Qwen3.6",
                apiKey: "not-required-local"
            ),
            configPath: configURL.path
        )

        let updated = try String(contentsOf: configURL, encoding: .utf8)
        XCTAssertTrue(updated.contains("  default: 'mlx-community/Qwen3.6'"))
        XCTAssertTrue(updated.contains("  provider: 'custom'"))
        XCTAssertTrue(updated.contains("  base_url: 'http://127.0.0.1:8080/v1'"))
        XCTAssertTrue(updated.contains("  api_key: 'not-required-local'"))
        XCTAssertTrue(updated.contains("  context_length: 262144"))
        XCTAssertTrue(updated.contains("agent:\n  max_turns: 60"))
        XCTAssertEqual(result.changedKeys, ["default", "provider", "base_url", "api_key"])
        XCTAssertNotNil(result.backupURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.backupURL!.path))
        XCTAssertEqual(try String(contentsOf: result.backupURL!, encoding: .utf8), original)
    }

    func testApplyDoesNotRewriteWhenConfigAlreadyMatches() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MLXServerManagerTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let configURL = temporaryDirectory.appendingPathComponent("config.yaml")
        let original = """
        model:
          default: 'model-a'
          provider: 'custom'
          base_url: 'http://127.0.0.1:8080/v1'
          api_key: 'not-required-local'
          context_length: 262144
        """
        try original.write(to: configURL, atomically: true, encoding: .utf8)

        let service = HermesAgentConfigService()
        let result = try service.apply(
            connection: HermesAgentConnectionSettings(
                baseURL: "http://127.0.0.1:8080/v1",
                modelID: "model-a",
                apiKey: "not-required-local"
            ),
            configPath: configURL.path
        )

        XCTAssertFalse(result.didChange)
        XCTAssertNil(result.backupURL)
        XCTAssertTrue(result.changedKeys.isEmpty)
        XCTAssertEqual(try String(contentsOf: configURL, encoding: .utf8), original)
    }

    func testUpdatedConfigTextAddsModelSectionWhenMissing() {
        let original = """
        agent:
          max_turns: 60
        """

        let update = HermesAgentConfigService.updatedConfigText(
            original,
            connection: HermesAgentConnectionSettings(
                baseURL: "http://127.0.0.1:8080/v1",
                modelID: "model-a",
                apiKey: ""
            )
        )

        XCTAssertTrue(update.text.hasPrefix("model:\n  default: 'model-a'\n  provider: 'custom'\n  base_url: 'http://127.0.0.1:8080/v1'\n  api_key: ''\n\nagent:"))
        XCTAssertEqual(update.changedKeys, ["default", "provider", "base_url", "api_key"])
    }
}
