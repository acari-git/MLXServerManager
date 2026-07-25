import Foundation

nonisolated enum RuntimeOptionCapabilityProbeResult: Equatable, Sendable {
    case available(flags: Set<String>)
    case unavailable
}

nonisolated protocol RuntimeOptionCapabilityProviding: Sendable {
    func capabilities(executablePath: String) async -> RuntimeOptionCapabilityProbeResult
}

actor RuntimeOptionCapabilityProvider: RuntimeOptionCapabilityProviding {
    private struct CacheKey: Hashable {
        let executablePath: String
        let fileSize: UInt64
        let modificationDate: Date
    }

    private let fileManager: FileManager
    private let timeout: TimeInterval
    private var cache: [CacheKey: Set<String>] = [:]

    init(
        fileManager: FileManager = .default,
        timeout: TimeInterval = 5
    ) {
        self.fileManager = fileManager
        self.timeout = timeout
    }

    func capabilities(executablePath: String) async -> RuntimeOptionCapabilityProbeResult {
        let normalizedPath = NSString(
            string: executablePath.trimmingCharacters(in: .whitespacesAndNewlines)
        ).expandingTildeInPath
        guard !normalizedPath.isEmpty,
              fileManager.fileExists(atPath: normalizedPath),
              fileManager.isExecutableFile(atPath: normalizedPath) else {
            return .unavailable
        }

        if let key = cacheKey(for: normalizedPath),
           let cachedFlags = cache[key] {
            return .available(flags: cachedFlags)
        }

        guard let result = await ShortLivedProcessRunner.runAsync(
            executablePath: normalizedPath,
            arguments: ["--help"],
            timeout: timeout
        ), !result.timedOut, !result.cancelled else {
            return .unavailable
        }

        var outputData = result.standardOutput
        outputData.append(Data("\n".utf8))
        outputData.append(result.standardError)
        guard let output = String(data: outputData, encoding: .utf8) else {
            return .unavailable
        }

        let flags = RuntimeCompatibilityService.parseFlags(output)
        guard !flags.isEmpty else {
            return .unavailable
        }

        if let key = cacheKey(for: normalizedPath) {
            cache = cache.filter { $0.key.executablePath != normalizedPath }
            cache[key] = flags
        }
        return .available(flags: flags)
    }

    private func cacheKey(for executablePath: String) -> CacheKey? {
        guard let attributes = try? fileManager.attributesOfItem(atPath: executablePath),
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
}
