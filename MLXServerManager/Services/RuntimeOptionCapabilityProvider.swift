import Foundation

nonisolated enum RuntimeOptionCapabilityProbeResult: Equatable, Sendable {
    case available(flags: Set<String>)
    case unavailable
}

nonisolated protocol RuntimeOptionCapabilityProviding: Sendable {
    func capabilities(executablePath: String, backend: InferenceBackend) async -> RuntimeOptionCapabilityProbeResult
}

actor RuntimeOptionCapabilityProvider: RuntimeOptionCapabilityProviding {
    private struct CacheKey: Hashable {
        let executablePath: String
        let backend: InferenceBackend
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

    func capabilities(executablePath: String, backend: InferenceBackend) async -> RuntimeOptionCapabilityProbeResult {
        let normalizedPath = NSString(
            string: executablePath.trimmingCharacters(in: .whitespacesAndNewlines)
        ).expandingTildeInPath
        guard !normalizedPath.isEmpty,
              fileManager.fileExists(atPath: normalizedPath),
              fileManager.isExecutableFile(atPath: normalizedPath) else {
            return .unavailable
        }

        if let key = cacheKey(for: normalizedPath, backend: backend),
           let cachedFlags = cache[key] {
            return .available(flags: cachedFlags)
        }

        // Rapid-MLX launches as `rapid-mlx serve <model> ...`, so serve-only flags
        // (e.g. --no-thinking) appear only in `serve --help`, not top-level `--help`.
        var helpInvocations: [[String]] = [["--help"]]
        if backend == .rapidMLX {
            helpInvocations.append(["serve", "--help"])
        }

        var flags = Set<String>()
        for arguments in helpInvocations {
            guard let result = await ShortLivedProcessRunner.runAsync(
                executablePath: normalizedPath,
                arguments: arguments,
                timeout: timeout
            ), !result.timedOut, !result.cancelled else {
                continue
            }
            var outputData = result.standardOutput
            outputData.append(Data("\n".utf8))
            outputData.append(result.standardError)
            guard let output = String(data: outputData, encoding: .utf8) else {
                continue
            }
            flags.formUnion(RuntimeCompatibilityService.parseFlags(output))
        }
        guard !flags.isEmpty else {
            return .unavailable
        }

        if let key = cacheKey(for: normalizedPath, backend: backend) {
            cache = cache.filter { $0.key.executablePath != normalizedPath }
            cache[key] = flags
        }
        return .available(flags: flags)
    }

    private func cacheKey(for executablePath: String, backend: InferenceBackend) -> CacheKey? {
        guard let attributes = try? fileManager.attributesOfItem(atPath: executablePath),
              let fileSize = attributes[.size] as? NSNumber,
              let modificationDate = attributes[.modificationDate] as? Date else {
            return nil
        }
        return CacheKey(
            executablePath: executablePath,
            backend: backend,
            fileSize: fileSize.uint64Value,
            modificationDate: modificationDate
        )
    }
}
