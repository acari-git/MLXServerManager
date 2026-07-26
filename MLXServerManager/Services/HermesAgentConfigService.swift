import Darwin
import Foundation

nonisolated struct HermesAgentConnectionSettings: Equatable {
    let baseURL: String
    let modelID: String
    let apiKey: String
}

nonisolated struct HermesAgentConfigInspection: Equatable {
    let configURL: URL
    let connection: HermesAgentConnectionSettings
    let diagnostics: [HermesAgentConfigDiagnostic]
}

nonisolated enum HermesAgentConfigDiagnosticSeverity: String, Equatable {
    case warning
    case error
}

nonisolated struct HermesAgentConfigDiagnostic: Equatable, Identifiable {
    let severity: HermesAgentConfigDiagnosticSeverity
    let line: Int?
    let message: String
    let blocksUpdate: Bool

    var id: String { "\(severity.rawValue)-\(line ?? 0)-\(message)" }
}

nonisolated struct HermesAgentConfigBackup: Equatable, Identifiable {
    let url: URL
    let modifiedAt: Date

    var id: String { url.path }
}

nonisolated struct HermesAgentSessionSummary: Codable, Equatable, Identifiable {
    let id: String
    let title: String?
    let source: String
    let model: String?
    let startedAt: Double
    let endedAt: Double?
    let messageCount: Int
    let toolCallCount: Int
    let inputTokens: Int
    let outputTokens: Int
    let cacheReadTokens: Int
    let cacheWriteTokens: Int
    let reasoningTokens: Int
    let cwd: String?
    let endReason: String?
    let archived: Int

    enum CodingKeys: String, CodingKey {
        case id, title, source, model, cwd, archived
        case startedAt = "started_at"
        case endedAt = "ended_at"
        case messageCount = "message_count"
        case toolCallCount = "tool_call_count"
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case cacheReadTokens = "cache_read_tokens"
        case cacheWriteTokens = "cache_write_tokens"
        case reasoningTokens = "reasoning_tokens"
        case endReason = "end_reason"
    }
}

nonisolated struct HermesAgentSessionMessage: Codable, Equatable, Identifiable {
    let id: Int
    let role: String
    let content: String?
    let toolName: String?
    let toolCalls: String?
    let timestamp: Double
    let tokenCount: Int?
    let finishReason: String?
    let active: Int
    let compacted: Int

    enum CodingKeys: String, CodingKey {
        case id, role, content, timestamp, active, compacted
        case toolName = "tool_name"
        case toolCalls = "tool_calls"
        case tokenCount = "token_count"
        case finishReason = "finish_reason"
    }
}

nonisolated struct HermesAgentConfigUpdateResult: Equatable {
    let configURL: URL
    let backupURL: URL?
    let changedKeys: [String]

    var didChange: Bool {
        backupURL != nil
    }
}

nonisolated enum HermesAgentConfigServiceError: LocalizedError, Equatable {
    case configPathMissing
    case configFileNotFound(String)
    case configPathIsDirectory(String)
    case unreadableConfig(String)
    case unreadableBackup(String)
    case restoreVerificationFailed(String)
    case configChangedDuringRestore(String)
    case unsupportedTabIndentation(line: Int)
    case unsafeConfigStructure([String])
    case backupNotFound(String)

    var errorDescription: String? {
        switch self {
        case .configPathMissing:
            "Hermes Agent config file path is not set."
        case let .configFileNotFound(path):
            "Hermes Agent config file was not found: \(path)"
        case let .configPathIsDirectory(path):
            "Hermes Agent config path is a directory: \(path)"
        case let .unreadableConfig(path):
            "Hermes Agent config file could not be read as UTF-8 text: \(path)"
        case let .unreadableBackup(path):
            "Hermes Agent backup file could not be read as UTF-8 text: \(path)"
        case let .restoreVerificationFailed(path):
            "Hermes Agent restore data could not be verified: \(path)"
        case let .configChangedDuringRestore(path):
            "Hermes Agent config changed while the restore was being prepared: \(path)"
        case let .unsupportedTabIndentation(line):
            "Hermes Agent config uses a tab for YAML indentation on line \(line). Replace indentation tabs with spaces before applying changes."
        case let .unsafeConfigStructure(messages):
            "Hermes Agent config contains structural errors that must be fixed before updating: \(messages.joined(separator: "; "))"
        case let .backupNotFound(path):
            "Hermes Agent backup file was not found for: \(path)"
        }
    }
}

nonisolated struct HermesAgentConfigService {
    var fileManager: FileManager
    var dateProvider: () -> Date
    private var dataReader: (URL) throws -> Data
    private var atomicReplacer: ((URL, URL) throws -> Void)?

    init(
        fileManager: FileManager = .default,
        dateProvider: @escaping () -> Date = Date.init,
        dataReader: @escaping (URL) throws -> Data = { try Data(contentsOf: $0) },
        atomicReplacer: ((URL, URL) throws -> Void)? = nil
    ) {
        self.fileManager = fileManager
        self.dateProvider = dateProvider
        self.dataReader = dataReader
        self.atomicReplacer = atomicReplacer
    }

    func inspect(configPath: String) throws -> HermesAgentConfigInspection {
        let configURL = try validatedConfigURL(configPath: configPath)
        guard let text = try? String(contentsOf: configURL, encoding: .utf8) else {
            throw HermesAgentConfigServiceError.unreadableConfig(configURL.path)
        }
        if let line = Self.firstTabIndentedLine(in: text) {
            throw HermesAgentConfigServiceError.unsupportedTabIndentation(line: line)
        }

        let values = Self.modelConnectionValues(in: text)
        return HermesAgentConfigInspection(
            configURL: configURL,
            connection: HermesAgentConnectionSettings(
                baseURL: values["base_url"] ?? "",
                modelID: values["default"] ?? "",
                apiKey: values["api_key"] ?? ""
            ),
            diagnostics: Self.diagnostics(in: text)
        )
    }

    func apply(
        connection: HermesAgentConnectionSettings,
        configPath: String
    ) throws -> HermesAgentConfigUpdateResult {
        let configURL = try validatedConfigURL(configPath: configPath)

        guard let originalText = try? String(contentsOf: configURL, encoding: .utf8) else {
            throw HermesAgentConfigServiceError.unreadableConfig(configURL.path)
        }

        let blockingDiagnostics = Self.diagnostics(in: originalText).filter(\.blocksUpdate)
        if !blockingDiagnostics.isEmpty {
            throw HermesAgentConfigServiceError.unsafeConfigStructure(
                blockingDiagnostics.map { diagnostic in
                    diagnostic.line.map { "Line \($0): \(diagnostic.message)" } ?? diagnostic.message
                }
            )
        }

        let update = try Self.updatedConfigText(originalText, connection: connection)
        guard update.text != originalText else {
            return HermesAgentConfigUpdateResult(
                configURL: configURL,
                backupURL: nil,
                changedKeys: []
            )
        }

        let backupURL = try makeBackupURL(for: configURL)
        try fileManager.copyItem(at: configURL, to: backupURL)
        try update.text.write(to: configURL, atomically: true, encoding: .utf8)

        return HermesAgentConfigUpdateResult(
            configURL: configURL,
            backupURL: backupURL,
            changedKeys: update.changedKeys
        )
    }

    private func validatedConfigURL(configPath: String) throws -> URL {
        let trimmedPath = configPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPath.isEmpty else {
            throw HermesAgentConfigServiceError.configPathMissing
        }
        let configURL = expandedConfigURL(from: trimmedPath)

        var isDirectory = ObjCBool(false)
        guard fileManager.fileExists(atPath: configURL.path, isDirectory: &isDirectory) else {
            throw HermesAgentConfigServiceError.configFileNotFound(configURL.path)
        }
        guard !isDirectory.boolValue else {
            throw HermesAgentConfigServiceError.configPathIsDirectory(configURL.path)
        }
        return configURL
    }

    func listSessions(configPath: String, limit: Int = 50) throws -> [HermesAgentSessionSummary] {
        let configURL = expandedConfigURL(from: configPath)
        let databaseURL = configURL.deletingLastPathComponent().appendingPathComponent("state.db")
        guard fileManager.fileExists(atPath: databaseURL.path) else {
            throw HermesAgentConfigServiceError.configFileNotFound(databaseURL.path)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        process.arguments = [
            "-readonly",
            "-json",
            databaseURL.path,
            "SELECT id, title, source, model, started_at, ended_at, message_count, tool_call_count, input_tokens, output_tokens, cache_read_tokens, cache_write_tokens, reasoning_tokens, cwd, end_reason, archived FROM sessions ORDER BY started_at DESC LIMIT \(max(1, min(limit, 200)));"
        ]
        let output = Pipe()
        let errors = Pipe()
        process.standardOutput = output
        process.standardError = errors
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let message = String(data: errors.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? databaseURL.path
            throw HermesAgentConfigServiceError.unreadableConfig(message.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        return try JSONDecoder().decode([HermesAgentSessionSummary].self, from: data)
    }

    func listSessionMessages(
        configPath: String,
        sessionID: String,
        limit: Int = 200
    ) throws -> [HermesAgentSessionMessage] {
        let configURL = expandedConfigURL(from: configPath)
        let databaseURL = configURL.deletingLastPathComponent().appendingPathComponent("state.db")
        guard fileManager.fileExists(atPath: databaseURL.path) else {
            throw HermesAgentConfigServiceError.configFileNotFound(databaseURL.path)
        }

        let escapedSessionID = sessionID.replacingOccurrences(of: "'", with: "''")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        process.arguments = [
            "-readonly",
            "-json",
            databaseURL.path,
            "SELECT id, role, content, tool_name, tool_calls, timestamp, token_count, finish_reason, active, compacted FROM messages WHERE session_id = '\(escapedSessionID)' ORDER BY timestamp ASC, id ASC LIMIT \(max(1, min(limit, 500)));"
        ]
        let output = Pipe()
        let errors = Pipe()
        process.standardOutput = output
        process.standardError = errors
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let message = String(data: errors.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? databaseURL.path
            throw HermesAgentConfigServiceError.unreadableConfig(message.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        return try JSONDecoder().decode([HermesAgentSessionMessage].self, from: data)
    }

    func expandedConfigURL(from path: String) -> URL {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed == "~" {
            return fileManager.homeDirectoryForCurrentUser
        }

        if trimmed.hasPrefix("~/") {
            return fileManager.homeDirectoryForCurrentUser
                .appendingPathComponent(String(trimmed.dropFirst(2)), isDirectory: false)
        }

        return URL(fileURLWithPath: trimmed)
    }

    static func updatedConfigText(
        _ text: String,
        connection: HermesAgentConnectionSettings
    ) throws -> (text: String, changedKeys: [String]) {
        if let line = firstTabIndentedLine(in: text) {
            throw HermesAgentConfigServiceError.unsupportedTabIndentation(line: line)
        }

        let hadFinalNewline = text.hasSuffix("\n")
        var lines = text.components(separatedBy: "\n")
        if hadFinalNewline {
            lines.removeLast()
        }

        let modelValues = [
            ("default", connection.modelID),
            ("base_url", connection.baseURL),
            ("api_key", connection.apiKey)
        ]
        let providerValue = ("provider", "custom")
        let insertedModelValues = [
            modelValues[0],
            providerValue,
            modelValues[1],
            modelValues[2]
        ]

        guard let modelIndex = lines.firstIndex(where: { line in
            line.trimmingCharacters(in: .whitespaces) == "model:"
        }) else {
            let modelBlock = insertedModelValues.map { key, value in
                "  \(key): \(yamlScalar(value))"
            }
            lines = ["model:"] + modelBlock + [""] + lines
            return (joinedLines(lines, hadFinalNewline: hadFinalNewline), insertedModelValues.map(\.0))
        }

        let modelIndent = leadingSpaceCount(lines[modelIndex])
        let childIndent = String(repeating: " ", count: modelIndent + 2)
        var blockEnd = modelIndex + 1
        while blockEnd < lines.count {
            let trimmed = lines[blockEnd].trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                blockEnd += 1
                continue
            }
            if leadingSpaceCount(lines[blockEnd]) <= modelIndent {
                break
            }
            blockEnd += 1
        }

        var foundKeys = Set<String>()
        var changedKeys: [String] = []
        var foundProvider = false
        let valuesByKey = Dictionary(uniqueKeysWithValues: insertedModelValues)

        if modelIndex + 1 < blockEnd {
            for index in (modelIndex + 1)..<blockEnd {
                let line = lines[index]
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("provider:") {
                    foundProvider = true
                    let indent = String(line.prefix(while: { $0 == " " }))
                    let replacement = "\(indent)\(providerValue.0): \(yamlScalar(providerValue.1))"
                    if line != replacement {
                        lines[index] = replacement
                        changedKeys.append(providerValue.0)
                    }
                    continue
                }

                guard let key = modelValues.map(\.0).first(where: { trimmed.hasPrefix("\($0):") }),
                      let value = valuesByKey[key] else {
                    continue
                }

                foundKeys.insert(key)
                let indent = String(line.prefix(while: { $0 == " " }))
                let replacement = "\(indent)\(key): \(yamlScalar(value))"
                if line != replacement {
                    lines[index] = replacement
                    changedKeys.append(key)
                }
            }
        }

        var insertionIndex = modelIndex + 1
        if !foundProvider {
            lines.insert("\(childIndent)\(providerValue.0): \(yamlScalar(providerValue.1))", at: insertionIndex)
            insertionIndex += 1
            changedKeys.append(providerValue.0)
        }
        for (key, value) in modelValues where !foundKeys.contains(key) {
            lines.insert("\(childIndent)\(key): \(yamlScalar(value))", at: insertionIndex)
            insertionIndex += 1
            changedKeys.append(key)
        }

        return (joinedLines(lines, hadFinalNewline: hadFinalNewline), changedKeys)
    }

    func listBackups(configPath: String) throws -> [HermesAgentConfigBackup] {
        let trimmedPath = configPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPath.isEmpty else {
            throw HermesAgentConfigServiceError.configPathMissing
        }
        let configURL = expandedConfigURL(from: trimmedPath)
        let directoryURL = configURL.deletingLastPathComponent()
        let prefix = "\(configURL.lastPathComponent).mlxservermanager-backup-"

        return try fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [
                .contentModificationDateKey,
                .isRegularFileKey,
                .isSymbolicLinkKey
            ],
            options: [.skipsHiddenFiles]
        )
            .compactMap { url -> HermesAgentConfigBackup? in
                guard url.lastPathComponent.hasPrefix(prefix),
                      let values = try? url.resourceValues(forKeys: [
                          .contentModificationDateKey,
                          .isRegularFileKey,
                          .isSymbolicLinkKey
                      ]),
                      values.isRegularFile == true,
                      values.isSymbolicLink != true else {
                    return nil
                }
                return HermesAgentConfigBackup(
                    url: url,
                    modifiedAt: values.contentModificationDate ?? .distantPast
                )
            }
            .sorted { $0.modifiedAt > $1.modifiedAt }
    }

    func inspectBackup(_ backup: HermesAgentConfigBackup) throws -> HermesAgentConfigInspection {
        guard let text = try? String(contentsOf: backup.url, encoding: .utf8) else {
            throw HermesAgentConfigServiceError.unreadableBackup(backup.url.path)
        }
        if let line = Self.firstTabIndentedLine(in: text) {
            throw HermesAgentConfigServiceError.unsupportedTabIndentation(line: line)
        }
        let values = Self.modelConnectionValues(in: text)
        return HermesAgentConfigInspection(
            configURL: backup.url,
            connection: HermesAgentConnectionSettings(
                baseURL: values["base_url"] ?? "",
                modelID: values["default"] ?? "",
                apiKey: values["api_key"] ?? ""
            ),
            diagnostics: Self.diagnostics(in: text)
        )
    }

    func restoreLatestBackup(configPath: String) throws -> URL {
        let configURL = expandedConfigURL(from: configPath)
        guard let latestBackup = try listBackups(configPath: configPath).first else {
            throw HermesAgentConfigServiceError.backupNotFound(configURL.path)
        }
        return try restoreBackup(latestBackup, configPath: configPath)
    }

    func restoreBackup(_ backup: HermesAgentConfigBackup, configPath: String) throws -> URL {
        let configURL = expandedConfigURL(from: configPath)
        let directoryURL = configURL.deletingLastPathComponent()
        let validBackups = try listBackups(configPath: configPath)
        guard validBackups.contains(where: { $0.url.standardizedFileURL == backup.url.standardizedFileURL }) else {
            throw HermesAgentConfigServiceError.backupNotFound(backup.url.path)
        }
        let backupURL = backup.url

        let backupData: Data
        do {
            backupData = try dataReader(backupURL)
        } catch {
            throw HermesAgentConfigServiceError.unreadableBackup(backupURL.path)
        }
        guard String(data: backupData, encoding: .utf8) != nil else {
            throw HermesAgentConfigServiceError.unreadableBackup(backupURL.path)
        }

        let stagingURL = directoryURL.appendingPathComponent(
            ".\(configURL.lastPathComponent).mlxservermanager-restore-\(UUID().uuidString)",
            isDirectory: false
        )
        defer {
            if fileManager.fileExists(atPath: stagingURL.path) {
                try? fileManager.removeItem(at: stagingURL)
            }
        }
        try backupData.write(to: stagingURL, options: [.atomic])
        guard try dataReader(stagingURL) == backupData else {
            throw HermesAgentConfigServiceError.restoreVerificationFailed(backupURL.path)
        }

        var configIsDirectory = ObjCBool(false)
        let configExists = fileManager.fileExists(
            atPath: configURL.path,
            isDirectory: &configIsDirectory
        )
        guard !configExists || !configIsDirectory.boolValue else {
            throw HermesAgentConfigServiceError.configPathIsDirectory(configURL.path)
        }

        if configExists {
            let originalConfigData = try dataReader(configURL)
            let safetyBackupURL = try makeBackupURL(for: configURL)
            try fileManager.copyItem(at: configURL, to: safetyBackupURL)
            guard try dataReader(safetyBackupURL) == originalConfigData else {
                throw HermesAgentConfigServiceError.restoreVerificationFailed(safetyBackupURL.path)
            }
            guard try dataReader(configURL) == originalConfigData else {
                throw HermesAgentConfigServiceError.configChangedDuringRestore(configURL.path)
            }
        }
        if let atomicReplacer {
            try atomicReplacer(stagingURL, configURL)
        } else {
            try Self.replaceAtomically(stagingURL, destinationURL: configURL)
        }
        return backupURL
    }

    private static func replaceAtomically(_ sourceURL: URL, destinationURL: URL) throws {
        let result = sourceURL.path.withCString { sourcePath in
            destinationURL.path.withCString { destinationPath in
                Darwin.rename(sourcePath, destinationPath)
            }
        }
        guard result == 0 else {
            let errorCode = errno
            throw NSError(
                domain: NSPOSIXErrorDomain,
                code: Int(errorCode),
                userInfo: [NSFilePathErrorKey: destinationURL.path]
            )
        }
    }

    private func makeBackupURL(for configURL: URL) throws -> URL {
        let stamp = Self.backupDateFormatter.string(from: dateProvider())
        let baseName = "\(configURL.lastPathComponent).mlxservermanager-backup-\(stamp)"
        var candidate = configURL.deletingLastPathComponent().appendingPathComponent(baseName)
        var suffix = 2

        while fileManager.fileExists(atPath: candidate.path) {
            candidate = configURL
                .deletingLastPathComponent()
                .appendingPathComponent("\(baseName)-\(suffix)")
            suffix += 1
        }

        return candidate
    }

    private static func yamlScalar(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "''"))'"
    }

    private static func modelConnectionValues(in text: String) -> [String: String] {
        let lines = text.components(separatedBy: "\n")
        guard let modelIndex = lines.firstIndex(where: {
            $0.trimmingCharacters(in: .whitespaces) == "model:"
        }) else {
            return [:]
        }

        let modelIndent = leadingSpaceCount(lines[modelIndex])
        let supportedKeys = Set(["default", "base_url", "api_key"])
        var values: [String: String] = [:]

        for line in lines.dropFirst(modelIndex + 1) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                continue
            }
            if leadingSpaceCount(line) <= modelIndent {
                break
            }
            guard let separator = trimmed.firstIndex(of: ":") else {
                continue
            }
            let key = String(trimmed[..<separator])
            guard supportedKeys.contains(key) else {
                continue
            }
            let rawValue = String(trimmed[trimmed.index(after: separator)...])
                .trimmingCharacters(in: .whitespaces)
            values[key] = decodedYAMLScalar(rawValue)
        }
        return values
    }

    static func diagnostics(in text: String) -> [HermesAgentConfigDiagnostic] {
        let lines = text.components(separatedBy: "\n")
        var diagnostics: [HermesAgentConfigDiagnostic] = []
        let modelLines = lines.enumerated().filter {
            $0.element.trimmingCharacters(in: .whitespaces) == "model:"
        }
        if modelLines.isEmpty {
            diagnostics.append(.init(severity: .error, line: nil, message: "Missing required model section.", blocksUpdate: false))
            return diagnostics
        }
        if modelLines.count > 1 {
            for duplicate in modelLines.dropFirst() {
                diagnostics.append(.init(severity: .error, line: duplicate.offset + 1, message: "Duplicate model section.", blocksUpdate: true))
            }
        }

        let modelIndex = modelLines[0].offset
        let modelIndent = leadingSpaceCount(lines[modelIndex])
        let requiredKeys = ["default", "provider", "base_url", "api_key"]
        var occurrences: [String: [Int]] = [:]
        for (offset, line) in lines.dropFirst(modelIndex + 1).enumerated() {
            let lineIndex = modelIndex + 1 + offset
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
            let indent = leadingSpaceCount(line)
            if indent <= modelIndent { break }
            guard let separator = trimmed.firstIndex(of: ":") else { continue }
            let key = String(trimmed[..<separator])
            if requiredKeys.contains(key) {
                occurrences[key, default: []].append(lineIndex + 1)
                if indent != modelIndent + 2 {
                    diagnostics.append(.init(severity: .error, line: lineIndex + 1, message: "Key '\(key)' must be directly nested under model.", blocksUpdate: true))
                }
            }
        }
        for key in requiredKeys {
            let lines = occurrences[key] ?? []
            if lines.isEmpty {
                diagnostics.append(.init(severity: .error, line: nil, message: "Missing required model.\(key) value.", blocksUpdate: false))
            } else if lines.count > 1 {
                for line in lines.dropFirst() {
                    diagnostics.append(.init(severity: .error, line: line, message: "Duplicate model.\(key) key.", blocksUpdate: true))
                }
            }
        }
        return diagnostics
    }

    private static func decodedYAMLScalar(_ rawValue: String) -> String {
        guard rawValue.count >= 2 else { return rawValue }
        if rawValue.hasPrefix("'") && rawValue.hasSuffix("'") {
            let inner = rawValue.dropFirst().dropLast()
            return inner.replacingOccurrences(of: "''", with: "'")
        }
        if rawValue.hasPrefix("\"") && rawValue.hasSuffix("\"") {
            return String(rawValue.dropFirst().dropLast())
        }
        return rawValue
    }

    private static func joinedLines(_ lines: [String], hadFinalNewline: Bool) -> String {
        var text = lines.joined(separator: "\n")
        if hadFinalNewline {
            text += "\n"
        }
        return text
    }

    private static func leadingSpaceCount(_ line: String) -> Int {
        line.prefix(while: { $0 == " " }).count
    }

    private static func firstTabIndentedLine(in text: String) -> Int? {
        for (offset, line) in text.components(separatedBy: "\n").enumerated() {
            let indentation = line.prefix(while: { $0 == " " || $0 == "\t" })
            if indentation.contains("\t") {
                return offset + 1
            }
        }
        return nil
    }

    private static var backupDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter
    }
}
