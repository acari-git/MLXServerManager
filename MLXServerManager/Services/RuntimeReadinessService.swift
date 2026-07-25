import Foundation

nonisolated protocol RuntimeReadinessAssessing: Sendable {
    func assess(settings: AppSettings) async -> [RuntimeReadinessReport]
}

actor RuntimeReadinessService: RuntimeReadinessAssessing {
    private let fileManager: FileManager
    private let mlxLMCapabilityProvider: any MLXLMServerCapabilityProviding

    init(
        fileManager: FileManager = .default,
        mlxLMCapabilityProvider: any MLXLMServerCapabilityProviding
    ) {
        self.fileManager = fileManager
        self.mlxLMCapabilityProvider = mlxLMCapabilityProvider
    }

    func assess(settings: AppSettings) async -> [RuntimeReadinessReport] {
        var reports: [RuntimeReadinessReport] = []
        for backend in InferenceBackend.allCases {
            reports.append(await assess(backend: backend, settings: settings))
        }
        return reports
    }

    private func assess(
        backend: InferenceBackend,
        settings: AppSettings
    ) async -> RuntimeReadinessReport {
        let configuredPath = settings.executablePath(for: backend)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let checkedAt = Date()

        guard !configuredPath.isEmpty else {
            return RuntimeReadinessReport(
                backend: backend,
                executablePath: configuredPath,
                issue: .pathNotConfigured,
                checkedAt: checkedAt
            )
        }

        let expandedPath = NSString(string: configuredPath).expandingTildeInPath
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: expandedPath, isDirectory: &isDirectory),
              !isDirectory.boolValue else {
            return RuntimeReadinessReport(
                backend: backend,
                executablePath: configuredPath,
                issue: .fileMissing,
                checkedAt: checkedAt
            )
        }

        guard fileManager.isExecutableFile(atPath: expandedPath) else {
            return RuntimeReadinessReport(
                backend: backend,
                executablePath: configuredPath,
                issue: .notExecutable,
                checkedAt: checkedAt
            )
        }

        guard backend == .mlxLM else {
            return RuntimeReadinessReport(
                backend: backend,
                executablePath: configuredPath,
                issue: .ready(supportedFlagCount: nil),
                checkedAt: checkedAt
            )
        }

        switch await mlxLMCapabilityProvider.capabilities(executablePath: expandedPath) {
        case let .available(capabilities):
            return RuntimeReadinessReport(
                backend: backend,
                executablePath: configuredPath,
                issue: .ready(supportedFlagCount: capabilities.supportedFlags.count),
                checkedAt: checkedAt
            )
        case .unavailable:
            return RuntimeReadinessReport(
                backend: backend,
                executablePath: configuredPath,
                issue: .capabilityProbeUnavailable,
                checkedAt: checkedAt
            )
        }
    }
}
