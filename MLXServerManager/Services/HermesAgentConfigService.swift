import Darwin
import Foundation

nonisolated struct HermesAgentConnectionSettings: Equatable {
    let baseURL: String
    let modelID: String
    let apiKey: String
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

    func apply(
        connection: HermesAgentConnectionSettings,
        configPath: String
    ) throws -> HermesAgentConfigUpdateResult {
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

        guard let originalText = try? String(contentsOf: configURL, encoding: .utf8) else {
            throw HermesAgentConfigServiceError.unreadableConfig(configURL.path)
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

    func restoreLatestBackup(configPath: String) throws -> URL {
        let trimmedPath = configPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPath.isEmpty else {
            throw HermesAgentConfigServiceError.configPathMissing
        }
        let configURL = expandedConfigURL(from: trimmedPath)
        let directoryURL = configURL.deletingLastPathComponent()
        let prefix = "\(configURL.lastPathComponent).mlxservermanager-backup-"
        let backupURLs = try fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [
                .contentModificationDateKey,
                .isRegularFileKey,
                .isSymbolicLinkKey
            ],
            options: [.skipsHiddenFiles]
        )
            .compactMap { url -> (url: URL, date: Date)? in
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
                return (url, values.contentModificationDate ?? .distantPast)
            }
            .sorted { $0.date > $1.date }
            .map(\.url)

        guard let latestBackupURL = backupURLs.first else {
            throw HermesAgentConfigServiceError.backupNotFound(configURL.path)
        }

        let backupData: Data
        do {
            backupData = try dataReader(latestBackupURL)
        } catch {
            throw HermesAgentConfigServiceError.unreadableBackup(latestBackupURL.path)
        }
        guard String(data: backupData, encoding: .utf8) != nil else {
            throw HermesAgentConfigServiceError.unreadableBackup(latestBackupURL.path)
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
            throw HermesAgentConfigServiceError.restoreVerificationFailed(latestBackupURL.path)
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
        return latestBackupURL
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
