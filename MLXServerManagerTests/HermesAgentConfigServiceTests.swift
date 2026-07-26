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

    func testApplyBlocksDuplicateKeysWithoutChangingFile() throws {
        let temporaryDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let configURL = temporaryDirectory.appendingPathComponent("config.yaml")
        let original = """
        model:
          default: model-a
          default: model-b
          provider: custom
          base_url: http://127.0.0.1:8080/v1
          api_key: ''
        """
        try original.write(to: configURL, atomically: true, encoding: .utf8)

        XCTAssertThrowsError(
            try HermesAgentConfigService().apply(
                connection: HermesAgentConnectionSettings(
                    baseURL: "http://127.0.0.1:9000/v1",
                    modelID: "model-c",
                    apiKey: "not-required-local"
                ),
                configPath: configURL.path
            )
        ) { error in
            guard case let HermesAgentConfigServiceError.unsafeConfigStructure(messages) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertTrue(messages.contains(where: { $0.contains("Duplicate model.default key") }))
        }

        XCTAssertEqual(try String(contentsOf: configURL, encoding: .utf8), original)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: temporaryDirectory.path), ["config.yaml"])
    }

    func testApplyRepairsMissingRequiredKeys() throws {
        let temporaryDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let configURL = temporaryDirectory.appendingPathComponent("config.yaml")
        try "model:\n  context_length: 4096\n".write(to: configURL, atomically: true, encoding: .utf8)

        let result = try HermesAgentConfigService().apply(
            connection: HermesAgentConnectionSettings(
                baseURL: "http://127.0.0.1:8080/v1",
                modelID: "model-a",
                apiKey: "not-required-local"
            ),
            configPath: configURL.path
        )

        let updated = try String(contentsOf: configURL, encoding: .utf8)
        XCTAssertTrue(result.didChange)
        XCTAssertTrue(updated.contains("  default: 'model-a'"))
        XCTAssertTrue(updated.contains("  provider: 'custom'"))
        XCTAssertTrue(updated.contains("  base_url: 'http://127.0.0.1:8080/v1'"))
        XCTAssertTrue(updated.contains("  api_key: 'not-required-local'"))
        XCTAssertTrue(updated.contains("  context_length: 4096"))
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

    func testInspectReadsCurrentModelConnectionWithoutChangingFile() throws {
        let temporaryDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let configURL = temporaryDirectory.appendingPathComponent("config.yaml")
        let original = """
        model:
          default: 'mlx-community/Qwen3.6'
          provider: 'custom'
          base_url: 'http://127.0.0.1:8080/v1'
          api_key: 'not-required-local'
          context_length: 262144
        agent:
          max_turns: 60
        """
        try original.write(to: configURL, atomically: true, encoding: .utf8)

        let inspection = try HermesAgentConfigService().inspect(configPath: configURL.path)

        XCTAssertEqual(inspection.configURL, configURL)
        XCTAssertEqual(
            inspection.connection,
            HermesAgentConnectionSettings(
                baseURL: "http://127.0.0.1:8080/v1",
                modelID: "mlx-community/Qwen3.6",
                apiKey: "not-required-local"
            )
        )
        XCTAssertEqual(try String(contentsOf: configURL, encoding: .utf8), original)
    }

    func testListBackupsReturnsOnlyMatchingRegularFilesNewestFirst() throws {
        let temporaryDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

        let configURL = temporaryDirectory.appendingPathComponent("config.yaml")
        try "model: {}".write(to: configURL, atomically: true, encoding: .utf8)

        let olderURL = temporaryDirectory.appendingPathComponent("config.yaml.mlxservermanager-backup-20260725-100000")
        let newerURL = temporaryDirectory.appendingPathComponent("config.yaml.mlxservermanager-backup-20260726-100000")
        let unrelatedURL = temporaryDirectory.appendingPathComponent("other.yaml.mlxservermanager-backup-20260726-100000")
        try "older".write(to: olderURL, atomically: true, encoding: .utf8)
        try "newer".write(to: newerURL, atomically: true, encoding: .utf8)
        try "unrelated".write(to: unrelatedURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 100)], ofItemAtPath: olderURL.path)
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSince1970: 200)], ofItemAtPath: newerURL.path)

        let backups = try HermesAgentConfigService().listBackups(configPath: configURL.path)

        XCTAssertEqual(backups.map { resolved($0.url) }, [resolved(newerURL), resolved(olderURL)])
        XCTAssertEqual(backups.map(\.modifiedAt), [
            Date(timeIntervalSince1970: 200),
            Date(timeIntervalSince1970: 100)
        ])
    }

    func testDiagnosticsDetectMissingDuplicateAndInvalidHierarchy() {
        let diagnostics = HermesAgentConfigService.diagnostics(in: """
        model:
          default: 'first'
          default: 'second'
            base_url: 'http://127.0.0.1:8080/v1'
        """)

        XCTAssertTrue(diagnostics.contains { $0.message == "Duplicate model.default key." })
        XCTAssertTrue(diagnostics.contains { $0.message == "Key 'base_url' must be directly nested under model." })
        XCTAssertTrue(diagnostics.contains { $0.message == "Missing required model.provider value." })
        XCTAssertTrue(diagnostics.contains { $0.message == "Missing required model.api_key value." })
    }

    func testDiagnosticsAcceptValidModelConnectionStructure() {
        let diagnostics = HermesAgentConfigService.diagnostics(in: """
        model:
          default: 'mlx-community/Qwen3.6'
          provider: 'custom'
          base_url: 'http://127.0.0.1:8080/v1'
          api_key: 'not-required-local'
        """)

        XCTAssertTrue(diagnostics.isEmpty)
    }

    func testListSessionsReadsNewestFirstAndHonorsLimit() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let configURL = directory.appendingPathComponent("config.yaml")
        try "model:\n".write(to: configURL, atomically: true, encoding: .utf8)
        let databaseURL = directory.appendingPathComponent("state.db")
        try executeSQLite(databaseURL: databaseURL, sql: """
        CREATE TABLE sessions (
          id TEXT PRIMARY KEY, title TEXT, source TEXT NOT NULL, model TEXT,
          started_at REAL NOT NULL, ended_at REAL, message_count INTEGER NOT NULL,
          tool_call_count INTEGER NOT NULL, input_tokens INTEGER NOT NULL,
          output_tokens INTEGER NOT NULL, cache_read_tokens INTEGER NOT NULL,
          cache_write_tokens INTEGER NOT NULL, reasoning_tokens INTEGER NOT NULL,
          cwd TEXT, end_reason TEXT, archived INTEGER NOT NULL
        );
        INSERT INTO sessions VALUES ('old','Old','cli','model-a',100,NULL,1,0,10,5,0,0,0,'/tmp','done',0);
        INSERT INTO sessions VALUES ('new','New','desktop','model-b',200,250,2,1,20,10,3,1,2,'/work','complete',1);
        """)

        let sessions = try HermesAgentConfigService().listSessions(configPath: configURL.path, limit: 1)

        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions[0].id, "new")
        XCTAssertEqual(sessions[0].title, "New")
        XCTAssertEqual(sessions[0].source, "desktop")
        XCTAssertEqual(sessions[0].model, "model-b")
        XCTAssertEqual(sessions[0].messageCount, 2)
        XCTAssertEqual(sessions[0].toolCallCount, 1)
        XCTAssertEqual(sessions[0].reasoningTokens, 2)
        XCTAssertEqual(sessions[0].archived, 1)
    }

    func testListSessionMessagesPreservesChronologyAndEscapesSessionID() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let configURL = directory.appendingPathComponent("config.yaml")
        try "model:\n".write(to: configURL, atomically: true, encoding: .utf8)
        let databaseURL = directory.appendingPathComponent("state.db")
        try executeSQLite(databaseURL: databaseURL, sql: """
        CREATE TABLE messages (
          id INTEGER PRIMARY KEY, session_id TEXT NOT NULL, role TEXT NOT NULL,
          content TEXT, tool_name TEXT, tool_calls TEXT, timestamp REAL NOT NULL,
          token_count INTEGER, finish_reason TEXT, active INTEGER NOT NULL,
          compacted INTEGER NOT NULL
        );
        INSERT INTO messages VALUES (2,'session''quoted','assistant','second',NULL,NULL,20,7,'stop',1,0);
        INSERT INTO messages VALUES (1,'session''quoted','user','first',NULL,NULL,10,3,NULL,1,0);
        INSERT INTO messages VALUES (3,'other','user','ignored',NULL,NULL,5,1,NULL,1,0);
        """)

        let messages = try HermesAgentConfigService().listSessionMessages(
            configPath: configURL.path,
            sessionID: "session'quoted"
        )

        XCTAssertEqual(messages.map(\.id), [1, 2])
        XCTAssertEqual(messages.map(\.role), ["user", "assistant"])
        XCTAssertEqual(messages.map(\.content), ["first", "second"])
        XCTAssertEqual(messages[1].tokenCount, 7)
        XCTAssertEqual(messages[1].finishReason, "stop")
    }

    private func executeSQLite(databaseURL: URL, sql: String) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        process.arguments = [databaseURL.path, sql]
        let errors = Pipe()
        process.standardError = errors
        try process.run()
        process.waitUntilExit()
        if process.terminationStatus != 0 {
            let message = String(data: errors.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "sqlite3 failed"
            throw NSError(domain: "HermesAgentConfigServiceTests", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: message])
        }
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
