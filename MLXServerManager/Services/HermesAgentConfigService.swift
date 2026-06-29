import Foundation

struct HermesAgentConnectionSettings: Equatable {
    let baseURL: String
    let modelID: String
    let apiKey: String
}

struct HermesAgentConfigUpdateResult: Equatable {
    let configURL: URL
    let backupURL: URL?
    let changedKeys: [String]

    var didChange: Bool {
        backupURL != nil
    }
}

enum HermesAgentConfigServiceError: LocalizedError, Equatable {
    case configPathMissing
    case configFileNotFound(String)
    case configPathIsDirectory(String)
    case unreadableConfig(String)

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
        }
    }
}

struct HermesAgentConfigService {
    var fileManager: FileManager = .default
    var dateProvider: () -> Date = Date.init

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

        let update = Self.updatedConfigText(originalText, connection: connection)
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
    ) -> (text: String, changedKeys: [String]) {
        let hadFinalNewline = text.hasSuffix("\n")
        var lines = text.components(separatedBy: "\n")
        if hadFinalNewline {
            lines.removeLast()
        }

        let modelValues = [
            ("default", connection.modelID),
            ("provider", "custom"),
            ("base_url", connection.baseURL),
            ("api_key", connection.apiKey)
        ]

        guard let modelIndex = lines.firstIndex(where: { line in
            line.trimmingCharacters(in: .whitespaces) == "model:"
        }) else {
            let modelBlock = modelValues.map { key, value in
                "  \(key): \(yamlScalar(value))"
            }
            lines = ["model:"] + modelBlock + [""] + lines
            return (joinedLines(lines, hadFinalNewline: hadFinalNewline), modelValues.map(\.0))
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
        let valuesByKey = Dictionary(uniqueKeysWithValues: modelValues)

        if modelIndex + 1 < blockEnd {
            for index in (modelIndex + 1)..<blockEnd {
                let line = lines[index]
                let trimmed = line.trimmingCharacters(in: .whitespaces)
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
        for (key, value) in modelValues where !foundKeys.contains(key) {
            lines.insert("\(childIndent)\(key): \(yamlScalar(value))", at: insertionIndex)
            insertionIndex += 1
            changedKeys.append(key)
        }

        return (joinedLines(lines, hadFinalNewline: hadFinalNewline), changedKeys)
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

    private static var backupDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter
    }
}
