import Foundation

nonisolated struct MLXLMServerCapabilities: Equatable, Sendable {
    let supportedFlags: Set<String>

    init(supportedFlags: Set<String>) {
        self.supportedFlags = supportedFlags
    }

    init?(helpOutput: String) {
        let supportedFlags = Self.parseFlags(from: helpOutput)
        guard !supportedFlags.isEmpty else {
            return nil
        }
        self.supportedFlags = supportedFlags
    }

    func unsupportedFlags(from requestedFlags: [String]) -> [String] {
        requestedFlags
            .filter { !supportedFlags.contains($0) }
            .sorted()
    }

    static func requestedOptionalFlags(for request: ModelLaunchRequest) -> [String] {
        guard request.backend == .mlxLM else {
            return []
        }

        let managedFlags: Set<String> = ["--model", "--host", "--port"]
        return Array(Set(
            ModelProcessManager.launchArguments(for: request)
                .compactMap(normalizedFlag)
                .filter { !managedFlags.contains($0) }
        )).sorted()
    }

    private static func parseFlags(from output: String) -> Set<String> {
        let pattern = #"--[A-Za-z0-9][A-Za-z0-9_-]*"#
        guard let expression = try? NSRegularExpression(pattern: pattern) else {
            return []
        }

        let range = NSRange(output.startIndex..<output.endIndex, in: output)
        return Set(expression.matches(in: output, range: range).compactMap { match in
            guard let range = Range(match.range, in: output) else {
                return nil
            }
            return String(output[range])
        })
    }

    private static func normalizedFlag(_ argument: String) -> String? {
        guard argument.hasPrefix("--"), argument.count > 2 else {
            return nil
        }
        return String(argument.split(separator: "=", maxSplits: 1)[0])
    }
}

nonisolated enum MLXLMServerCapabilityProbeResult: Equatable, Sendable {
    case available(MLXLMServerCapabilities)
    case unavailable
}

nonisolated protocol MLXLMServerCapabilityProviding: Sendable {
    func capabilities(executablePath: String) async -> MLXLMServerCapabilityProbeResult
}

actor MLXLMServerCapabilityProvider: MLXLMServerCapabilityProviding {
    private struct CacheKey: Hashable {
        let executablePath: String
        let fileSize: UInt64
        let modificationDate: Date
    }

    private var cachedResults: [CacheKey: MLXLMServerCapabilities] = [:]
    private let timeout: TimeInterval

    init(timeout: TimeInterval = 5) {
        self.timeout = timeout
    }

    func capabilities(executablePath: String) async -> MLXLMServerCapabilityProbeResult {
        let normalizedPath = executablePath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let cacheKey = Self.cacheKey(executablePath: normalizedPath) else {
            return await Self.probe(executablePath: normalizedPath, timeout: timeout)
        }

        if let cachedCapabilities = cachedResults[cacheKey] {
            return .available(cachedCapabilities)
        }

        let result = await Self.probe(executablePath: normalizedPath, timeout: timeout)
        guard case let .available(capabilities) = result else {
            return result
        }

        cachedResults = cachedResults.filter { $0.key.executablePath != normalizedPath }
        cachedResults[cacheKey] = capabilities
        return result
    }

    private nonisolated static func cacheKey(executablePath: String) -> CacheKey? {
        guard !executablePath.isEmpty,
              let attributes = try? FileManager.default.attributesOfItem(atPath: executablePath),
              let fileSize = attributes[.size] as? NSNumber,
              let modificationDate = attributes[.modificationDate] as? Date else {
            return nil
        }

        return CacheKey(
            executablePath: executablePath,
            fileSize: fileSize.uint64Value,
            modificationDate: modificationDate
        )
    }

    private nonisolated static func probe(
        executablePath: String,
        timeout: TimeInterval
    ) async -> MLXLMServerCapabilityProbeResult {
        guard let result = await ShortLivedProcessRunner.runAsync(
            executablePath: executablePath,
            arguments: ["--help"],
            timeout: timeout
        ), !result.timedOut, !result.cancelled else {
            return .unavailable
        }

        var combinedOutput = result.standardOutput
        combinedOutput.append(Data("\n".utf8))
        combinedOutput.append(result.standardError)
        guard let output = String(data: combinedOutput, encoding: .utf8),
              let capabilities = MLXLMServerCapabilities(helpOutput: output) else {
            return .unavailable
        }
        return .available(capabilities)
    }
}
