import Foundation

nonisolated protocol RuntimeSetupAssisting: Sendable {
    func discover(settings: AppSettings) async -> [RuntimeSetupCandidate]
}

actor RuntimeSetupAssistantService: RuntimeSetupAssisting {
    private let fileManager: FileManager
    private let environment: [String: String]
    private let homeDirectory: String
    private let versionProvider: MLXLMVersionProvider

    init(
        fileManager: FileManager = .default,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        homeDirectory: String = FileManager.default.homeDirectoryForCurrentUser.path,
        versionProvider: MLXLMVersionProvider = MLXLMVersionProvider()
    ) {
        self.fileManager = fileManager
        self.environment = environment
        self.homeDirectory = homeDirectory
        self.versionProvider = versionProvider
    }

    func discover(settings: AppSettings) async -> [RuntimeSetupCandidate] {
        var candidates: [RuntimeSetupCandidate] = []
        for backend in InferenceBackend.allCases {
            for candidate in candidatePaths(backend: backend, settings: settings) {
                guard fileManager.fileExists(atPath: candidate.path),
                      fileManager.isExecutableFile(atPath: candidate.path) else {
                    continue
                }
                let version = await versionProvider.version(
                    executablePath: candidate.path,
                    backend: backend
                )
                candidates.append(
                    RuntimeSetupCandidate(
                        backend: backend,
                        executablePath: candidate.path,
                        version: version,
                        source: candidate.source
                    )
                )
            }
        }

        return candidates
            .reduce(into: [String: RuntimeSetupCandidate]()) { partialResult, candidate in
                partialResult[candidate.id] = preferred(existing: partialResult[candidate.id], candidate: candidate)
            }
            .values
            .sorted { lhs, rhs in
                if lhs.backend != rhs.backend {
                    return lhs.backend.rawValue < rhs.backend.rawValue
                }
                if sourceRank(lhs.source) != sourceRank(rhs.source) {
                    return sourceRank(lhs.source) < sourceRank(rhs.source)
                }
                return lhs.executablePath < rhs.executablePath
            }
    }

    private func candidatePaths(
        backend: InferenceBackend,
        settings: AppSettings
    ) -> [(path: String, source: RuntimeSetupCandidateSource)] {
        let executableNames: [String]
        switch backend {
        case .mlxLM:
            executableNames = ["mlx_lm.server", "mlx-lm-server"]
        case .rapidMLX:
            executableNames = ["rapid-mlx", "rapid_mlx"]
        }

        var result: [(String, RuntimeSetupCandidateSource)] = []
        let configured = expanded(settings.executablePath(for: backend))
        if !configured.isEmpty {
            result.append((configured, .configured))
        }

        let pathDirectories = environment["PATH"]?
            .split(separator: ":")
            .map(String.init) ?? []
        for directory in pathDirectories {
            for name in executableNames {
                result.append((URL(fileURLWithPath: directory).appendingPathComponent(name).path, .environmentPath))
            }
        }

        let commonDirectories = ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin"]
        for directory in commonDirectories {
            for name in executableNames {
                result.append((URL(fileURLWithPath: directory).appendingPathComponent(name).path, .commonLocation))
            }
        }

        let userDirectories = [
            "\(homeDirectory)/.local/bin",
            "\(homeDirectory)/.venv/bin",
            "\(homeDirectory)/mlx-gui/.venv/bin"
        ]
        for directory in userDirectories {
            for name in executableNames {
                result.append((URL(fileURLWithPath: directory).appendingPathComponent(name).path, .userEnvironment))
            }
        }

        return result
    }

    private func expanded(_ path: String) -> String {
        NSString(string: path.trimmingCharacters(in: .whitespacesAndNewlines)).expandingTildeInPath
    }

    private func preferred(
        existing: RuntimeSetupCandidate?,
        candidate: RuntimeSetupCandidate
    ) -> RuntimeSetupCandidate {
        guard let existing else { return candidate }
        return sourceRank(candidate.source) < sourceRank(existing.source) ? candidate : existing
    }

    private func sourceRank(_ source: RuntimeSetupCandidateSource) -> Int {
        switch source {
        case .configured: 0
        case .environmentPath: 1
        case .commonLocation: 2
        case .userEnvironment: 3
        }
    }
}
