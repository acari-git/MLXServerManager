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

    func testUpdatedConfigTextAddsModelSectionWhenMissing() throws {
        let original = """
        agent:
          max_turns: 60
        """

        let update = try HermesAgentConfigService.updatedConfigText(
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

    func testApplyRejectsTabIndentedYamlWithoutChangingTheFile() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MLXServerManagerTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let configURL = temporaryDirectory.appendingPathComponent("config.yaml")
        let original = "model:\n\tdefault: old-model\nagent:\n  max_turns: 60\n"
        try original.write(to: configURL, atomically: true, encoding: .utf8)

        let service = HermesAgentConfigService()
        XCTAssertThrowsError(
            try service.apply(
                connection: HermesAgentConnectionSettings(
                    baseURL: "http://127.0.0.1:8080/v1",
                    modelID: "model-a",
                    apiKey: "not-required-local"
                ),
                configPath: configURL.path
            )
        ) { error in
            XCTAssertEqual(
                error as? HermesAgentConfigServiceError,
                .unsupportedTabIndentation(line: 2)
            )
        }

        XCTAssertEqual(try String(contentsOf: configURL, encoding: .utf8), original)
        XCTAssertEqual(
            try FileManager.default.contentsOfDirectory(atPath: temporaryDirectory.path),
            ["config.yaml"]
        )
    }

    func testRestoreLatestBackupAtomicallyReplacesConfigAndPreservesSafetyBackup() throws {
        let temporaryDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let configURL = temporaryDirectory.appendingPathComponent("config.yaml")
        let original = "model:\n  default: current-model\n"
        let restored = "model:\n  default: restored-model\n"
        try original.write(to: configURL, atomically: true, encoding: .utf8)
        let sourceBackupURL = temporaryDirectory
            .appendingPathComponent("config.yaml.mlxservermanager-backup-20260101-000000")
        try restored.write(to: sourceBackupURL, atomically: true, encoding: .utf8)

        let service = HermesAgentConfigService(
            dateProvider: { Date(timeIntervalSince1970: 1_782_000_000) }
        )
        let restoredBackupURL = try service.restoreLatestBackup(configPath: configURL.path)

        XCTAssertEqual(resolved(restoredBackupURL), resolved(sourceBackupURL))
        XCTAssertEqual(try String(contentsOf: configURL, encoding: .utf8), restored)
        let backupURLs = try backupURLs(in: temporaryDirectory)
        XCTAssertEqual(backupURLs.count, 2)
        let safetyBackupURL = try XCTUnwrap(
            backupURLs.first { resolved($0) != resolved(sourceBackupURL) }
        )
        XCTAssertEqual(try String(contentsOf: safetyBackupURL, encoding: .utf8), original)
    }

    func testRestoreLatestBackupWriteFailureLeavesCurrentConfigUnchanged() throws {
        let temporaryDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let configURL = temporaryDirectory.appendingPathComponent("config.yaml")
        let originalData = Data("model:\n  default: current-model\n".utf8)
        try originalData.write(to: configURL)
        let sourceBackupURL = temporaryDirectory
            .appendingPathComponent("config.yaml.mlxservermanager-backup-20260101-000000")
        try Data("model:\n  default: restored-model\n".utf8).write(to: sourceBackupURL)
        let service = HermesAgentConfigService(
            atomicReplacer: { _, _ in
                throw NSError(domain: "HermesAgentConfigServiceTests", code: 1)
            }
        )

        XCTAssertThrowsError(try service.restoreLatestBackup(configPath: configURL.path))
        XCTAssertEqual(try Data(contentsOf: configURL), originalData)
        XCTAssertTrue(FileManager.default.fileExists(atPath: sourceBackupURL.path))
        XCTAssertEqual(try backupURLs(in: temporaryDirectory).count, 2)
    }

    func testRestoreLatestBackupRejectsInvalidUTF8BeforeTouchingCurrentConfig() throws {
        let temporaryDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let configURL = temporaryDirectory.appendingPathComponent("config.yaml")
        let originalData = Data("model:\n  default: current-model\n".utf8)
        try originalData.write(to: configURL)
        let sourceBackupURL = temporaryDirectory
            .appendingPathComponent("config.yaml.mlxservermanager-backup-20260101-000000")
        try Data([0xC3, 0x28]).write(to: sourceBackupURL)
        let service = HermesAgentConfigService()

        XCTAssertThrowsError(try service.restoreLatestBackup(configPath: configURL.path)) { error in
            guard case let HermesAgentConfigServiceError.unreadableBackup(path) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertEqual(URL(fileURLWithPath: path).lastPathComponent, sourceBackupURL.lastPathComponent)
        }
        XCTAssertEqual(try Data(contentsOf: configURL), originalData)
        XCTAssertEqual(
            try backupURLs(in: temporaryDirectory).map(resolved),
            [resolved(sourceBackupURL)]
        )
    }

    func testRestoreLatestBackupCreatesMissingConfigWithoutDeletingBackup() throws {
        let temporaryDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let configURL = temporaryDirectory.appendingPathComponent("config.yaml")
        let restoredData = Data("model:\n  default: restored-model\n".utf8)
        let sourceBackupURL = temporaryDirectory
            .appendingPathComponent("config.yaml.mlxservermanager-backup-20260101-000000")
        try restoredData.write(to: sourceBackupURL)

        let restoredBackupURL = try HermesAgentConfigService()
            .restoreLatestBackup(configPath: configURL.path)

        XCTAssertEqual(resolved(restoredBackupURL), resolved(sourceBackupURL))
        XCTAssertEqual(try Data(contentsOf: configURL), restoredData)
        XCTAssertTrue(FileManager.default.fileExists(atPath: sourceBackupURL.path))
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("MLXServerManagerTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func backupURLs(in directoryURL: URL) throws -> [URL] {
        try FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil
        )
        .filter { $0.lastPathComponent.hasPrefix("config.yaml.mlxservermanager-backup-") }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    private func resolved(_ url: URL) -> URL {
        url.resolvingSymlinksInPath()
    }
}
