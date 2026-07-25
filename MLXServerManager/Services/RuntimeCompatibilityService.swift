import Foundation

nonisolated protocol RuntimeCompatibilityAssessing: Sendable {
    func assess(settings: AppSettings) async -> [RuntimeCompatibilityReport]
}

actor RuntimeCompatibilityService: RuntimeCompatibilityAssessing {
    private let fileManager: FileManager
    private let versionProvider: MLXLMVersionProvider
    private let timeout: TimeInterval

    init(
        fileManager: FileManager = .default,
        versionProvider: MLXLMVersionProvider = MLXLMVersionProvider(),
        timeout: TimeInterval = 5
    ) {
        self.fileManager = fileManager
        self.versionProvider = versionProvider
        self.timeout = timeout
    }

    func assess(settings: AppSettings) async -> [RuntimeCompatibilityReport] {
        var reports: [RuntimeCompatibilityReport] = []
        for backend in InferenceBackend.allCases {
            let configuredPath = settings.executablePath(for: backend)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let executablePath = NSString(string: configuredPath).expandingTildeInPath
            guard !executablePath.isEmpty,
                  fileManager.fileExists(atPath: executablePath),
                  fileManager.isExecutableFile(atPath: executablePath) else {
                reports.append(
                    RuntimeCompatibilityReport(
                        backend: backend,
                        executablePath: configuredPath,
                        version: nil,
                        supportedFlags: nil,
                        features: RuntimeCompatibilityFeature.allCases.map {
                            RuntimeCompatibilityFeatureResult(
                                feature: $0,
                                support: .unknown,
                                detectedFlags: []
                            )
                        },
                        checkedAt: Date()
                    )
                )
                continue
            }

            let version = await versionProvider.version(
                executablePath: executablePath,
                backend: backend
            )
            let flags = await probeFlags(executablePath: executablePath)
            reports.append(
                RuntimeCompatibilityReport(
                    backend: backend,
                    executablePath: configuredPath,
                    version: version,
                    supportedFlags: flags,
                    features: featureResults(flags: flags),
                    checkedAt: Date()
                )
            )
        }
        return reports
    }

    private func probeFlags(executablePath: String) async -> Set<String>? {
        guard let result = await ShortLivedProcessRunner.runAsync(
            executablePath: executablePath,
            arguments: ["--help"],
            timeout: timeout
        ), !result.timedOut, !result.cancelled else {
            return nil
        }

        var data = result.standardOutput
        data.append(Data("\n".utf8))
        data.append(result.standardError)
        guard let output = String(data: data, encoding: .utf8) else {
            return nil
        }
        let flags = Self.parseFlags(output)
        return flags.isEmpty ? nil : flags
    }

    nonisolated static func parseFlags(_ output: String) -> Set<String> {
        guard let expression = try? NSRegularExpression(
            pattern: #"--[A-Za-z0-9][A-Za-z0-9_-]*"#
        ) else {
            return []
        }
        let range = NSRange(output.startIndex..<output.endIndex, in: output)
        return Set(expression.matches(in: output, range: range).compactMap { match in
            guard let range = Range(match.range, in: output) else { return nil }
            return String(output[range])
        })
    }

    private func featureResults(flags: Set<String>?) -> [RuntimeCompatibilityFeatureResult] {
        RuntimeCompatibilityFeature.allCases.map { feature in
            guard let flags else {
                return RuntimeCompatibilityFeatureResult(
                    feature: feature,
                    support: .unknown,
                    detectedFlags: []
                )
            }
            let detected = feature.recognizedFlags.intersection(flags).sorted()
            let support = Self.support(
                feature: feature,
                flags: flags,
                detectedFlags: detected
            )
            return RuntimeCompatibilityFeatureResult(
                feature: feature,
                support: support,
                detectedFlags: detected
            )
        }
    }

    nonisolated private static func support(
        feature: RuntimeCompatibilityFeature,
        flags: Set<String>,
        detectedFlags: [String]
    ) -> RuntimeCompatibilitySupport {
        guard !detectedFlags.isEmpty else { return .unsupported }
        switch feature {
        case .hostAndPort, .speculativeDecoding:
            return feature.recognizedFlags.isSubset(of: flags) ? .supported : .partial
        case .modelSelection, .cors, .chatTemplate, .trustRemoteCode, .reasoningControl, .toolCallParser:
            return .supported
        }
    }
}
