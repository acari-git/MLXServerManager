import Foundation

nonisolated struct PlatformCompatibilityService: Sendable {
    let minimumSupportedVersion: String

    init(minimumSupportedVersion: String = "15.0") {
        self.minimumSupportedVersion = minimumSupportedVersion
    }

    func assess() -> PlatformCompatibilityReport {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        let currentVersion = "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
        #if arch(arm64)
        let architecture = "arm64"
        let isAppleSilicon = true
        #elseif arch(x86_64)
        let architecture = "x86_64"
        let isAppleSilicon = false
        #else
        let architecture = "unknown"
        let isAppleSilicon = false
        #endif
        let currentComponents = [version.majorVersion, version.minorVersion]
        let minimumComponents = minimumSupportedVersion.split(separator: ".").compactMap { Int($0) }
        let meetsMinimum = currentComponents.lexicographicallyPrecedes(minimumComponents) == false
        return PlatformCompatibilityReport(
            minimumSupportedVersion: minimumSupportedVersion,
            currentVersion: currentVersion,
            architecture: architecture,
            isAppleSilicon: isAppleSilicon,
            status: isAppleSilicon && meetsMinimum ? .ready : .blocking,
            checkedAt: Date()
        )
    }
}

nonisolated struct EvidenceFreshnessService: @unchecked Sendable {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func capture(
        settings: AppSettings,
        model: ModelConfig?,
        benchmarkSession: BenchmarkSessionResult?,
        systemMemory: SystemMemorySnapshot
    ) -> [EvidenceFingerprint] {
        let now = Date()
        return EvidenceDomain.allCases.map { domain in
            EvidenceFingerprint(
                domain: domain,
                value: fingerprint(
                    for: domain,
                    settings: settings,
                    model: model,
                    benchmarkSession: benchmarkSession,
                    systemMemory: systemMemory
                ),
                capturedAt: now
            )
        }
    }

    func compare(
        captured: [EvidenceFingerprint],
        current: [EvidenceFingerprint]
    ) -> [EvidenceFreshnessItem] {
        let capturedByDomain = Dictionary(uniqueKeysWithValues: captured.map { ($0.domain, $0) })
        let currentByDomain = Dictionary(uniqueKeysWithValues: current.map { ($0.domain, $0) })
        return EvidenceDomain.allCases.map { domain in
            let previous = capturedByDomain[domain]
            let latest = currentByDomain[domain]
            let status: EvidenceFreshnessStatus
            if previous == nil || previous?.value == nil {
                status = .unavailable
            } else if previous?.value == latest?.value {
                status = .current
            } else {
                status = .stale
            }
            return EvidenceFreshnessItem(
                domain: domain,
                status: status,
                capturedAt: previous?.capturedAt,
                currentFingerprint: latest?.value,
                capturedFingerprint: previous?.value,
                reason: nil
            )
        }
    }

    private func fingerprint(
        for domain: EvidenceDomain,
        settings: AppSettings,
        model: ModelConfig?,
        benchmarkSession: BenchmarkSessionResult?,
        systemMemory: SystemMemorySnapshot
    ) -> String? {
        switch domain {
        case .runtime:
            guard let model else { return nil }
            let path = expanded(settings.executablePath(for: model.resolvedBackend))
            guard !path.isEmpty else { return nil }
            return stableFingerprint([path, fileSignature(path: path)])
        case .profile:
            guard let model else { return nil }
            let options = model.advancedLaunchOptions.map { String(describing: $0) } ?? "none"
            return stableFingerprint([
                model.id,
                model.displayName,
                model.resolvedBackend.rawValue,
                model.host,
                String(model.serverPort),
                String(model.enableThinking),
                options
            ])
        case .model:
            guard let model,
                  let rawPath = ModelAvailabilityPathFormatter.localPathCandidate(for: model) else {
                return nil
            }
            let path = URL(fileURLWithPath: rawPath).standardizedFileURL.path
            return stableFingerprint([
                path,
                fileSignature(path: path),
                fileSignature(path: URL(fileURLWithPath: path).appendingPathComponent("config.json").path),
                fileSignature(path: URL(fileURLWithPath: path).appendingPathComponent("tokenizer_config.json").path),
                fileSignature(path: URL(fileURLWithPath: path).appendingPathComponent("model.safetensors.index.json").path)
            ])
        case .endpoint:
            guard let model else { return nil }
            return stableFingerprint([model.host.lowercased(), String(model.serverPort)])
        case .memory:
            let available = systemMemory.availableGigabytes.map { String(format: "%.1f", $0) } ?? "unknown"
            return stableFingerprint([
                String(format: "%.1f", systemMemory.totalGigabytes),
                available
            ])
        case .benchmark:
            guard let benchmarkSession else { return nil }
            return stableFingerprint([
                benchmarkSession.id.uuidString,
                benchmarkSession.timestamp.timeIntervalSince1970.description,
                benchmarkSession.executionFingerprint ?? "none",
                String(benchmarkSession.aggregate.successfulSampleCount)
            ])
        case .hermes:
            let path = expanded(settings.hermesConfigPath)
            guard !path.isEmpty else { return nil }
            return stableFingerprint([path, fileSignature(path: path)])
        }
    }

    private func expanded(_ path: String) -> String {
        NSString(string: path.trimmingCharacters(in: .whitespacesAndNewlines)).expandingTildeInPath
    }

    private func fileSignature(path: String) -> String {
        guard let attributes = try? fileManager.attributesOfItem(atPath: path) else {
            return "missing"
        }
        let size = (attributes[.size] as? NSNumber)?.uint64Value ?? 0
        let modification = (attributes[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
        return "\(size):\(modification)"
    }

    private func stableFingerprint(_ values: [String]) -> String {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in values.joined(separator: "\u{1F}").utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return String(format: "%016llx", hash)
    }
}

nonisolated protocol RuntimeEnvironmentDoctorAssessing: Sendable {
    func assess(settings: AppSettings) async -> [RuntimeDoctorReport]
}

actor RuntimeEnvironmentDoctorService: RuntimeEnvironmentDoctorAssessing {
    private let fileManager: FileManager
    private let timeout: TimeInterval

    init(fileManager: FileManager = .default, timeout: TimeInterval = 5) {
        self.fileManager = fileManager
        self.timeout = timeout
    }

    func assess(settings: AppSettings) async -> [RuntimeDoctorReport] {
        var reports: [RuntimeDoctorReport] = []
        for backend in InferenceBackend.allCases {
            guard !Task.isCancelled else { break }
            reports.append(await assess(backend: backend, rawPath: settings.executablePath(for: backend)))
        }
        return reports
    }

    private func assess(backend: InferenceBackend, rawPath: String) async -> RuntimeDoctorReport {
        let checkedAt = Date()
        let path = NSString(string: rawPath.trimmingCharacters(in: .whitespacesAndNewlines)).expandingTildeInPath
        guard !path.isEmpty else {
            return report(
                backend: backend,
                path: path,
                version: nil,
                interpreter: nil,
                checkedAt: checkedAt,
                issues: [issue(
                    backend: backend,
                    kind: .pathNotConfigured,
                    severity: .blocking,
                    title: "Runtime path is not configured",
                    detail: "Choose an executable path in Settings before starting this backend.",
                    command: nil
                )]
            )
        }
        guard fileManager.fileExists(atPath: path) else {
            return report(
                backend: backend,
                path: path,
                version: nil,
                interpreter: nil,
                checkedAt: checkedAt,
                issues: [issue(
                    backend: backend,
                    kind: .pathMissing,
                    severity: .blocking,
                    title: "Runtime executable is missing",
                    detail: "The configured executable path does not exist.",
                    command: nil
                )]
            )
        }
        guard fileManager.isExecutableFile(atPath: path) else {
            return report(
                backend: backend,
                path: path,
                version: nil,
                interpreter: nil,
                checkedAt: checkedAt,
                issues: [issue(
                    backend: backend,
                    kind: .notExecutable,
                    severity: .blocking,
                    title: "Runtime file is not executable",
                    detail: "Review the file permissions before using this runtime.",
                    command: "chmod +x \(shellQuote(path))"
                )]
            )
        }

        var issues: [RuntimeDoctorIssue] = []
        let interpreter = interpreterPath(for: path)
        if let interpreter,
           interpreter.hasPrefix("/"),
           !fileManager.fileExists(atPath: interpreter) {
            issues.append(issue(
                backend: backend,
                kind: .interpreterMissing,
                severity: .blocking,
                title: "Script interpreter is missing",
                detail: "The executable shebang references an interpreter that is not present.",
                command: nil
            ))
        }
        if binaryArchitecture(for: path) == "x86_64" {
            issues.append(issue(
                backend: backend,
                kind: .unsupportedArchitecture,
                severity: .blocking,
                title: "Intel runtime binary detected",
                detail: "Use an arm64 runtime build for Apple Silicon and MLX.",
                command: nil
            ))
        }

        async let versionResult = ShortLivedProcessRunner.runAsync(
            executablePath: path,
            arguments: ["--version"],
            timeout: timeout
        )
        async let helpResult = ShortLivedProcessRunner.runAsync(
            executablePath: path,
            arguments: ["--help"],
            timeout: timeout
        )
        let versionProcess = await versionResult
        let helpProcess = await helpResult
        let combined = [versionProcess, helpProcess]
            .compactMap { processOutput($0) }
            .joined(separator: "\n")
        if combined.localizedCaseInsensitiveContains("ModuleNotFoundError")
            || combined.localizedCaseInsensitiveContains("No module named") {
            issues.append(issue(
                backend: backend,
                kind: .dependencyFailure,
                severity: .blocking,
                title: "Python dependency import failed",
                detail: "The configured executable starts, but its Python environment cannot import a required module.",
                command: nil
            ))
        }
        let version = firstUsefulLine(processOutput(versionProcess))
        if version == nil {
            issues.append(issue(
                backend: backend,
                kind: .versionUnavailable,
                severity: .warning,
                title: "Runtime version was not reported",
                detail: "The executable did not return a usable version line.",
                command: "\(shellQuote(path)) --version"
            ))
        }
        let helpOutput = processOutput(helpProcess) ?? ""
        if RuntimeCompatibilityService.parseFlags(helpOutput).isEmpty {
            issues.append(issue(
                backend: backend,
                kind: .helpUnavailable,
                severity: .warning,
                title: "Runtime help flags were not detected",
                detail: "Capability-aware option checks will remain Unknown until help output can be parsed.",
                command: "\(shellQuote(path)) --help"
            ))
        }
        if issues.isEmpty {
            issues.append(issue(
                backend: backend,
                kind: .ready,
                severity: .info,
                title: "Runtime environment is ready",
                detail: "The executable exists, is executable, and responded to bounded inspection commands.",
                command: nil
            ))
        }
        return report(
            backend: backend,
            path: path,
            version: version,
            interpreter: interpreter,
            checkedAt: checkedAt,
            issues: issues
        )
    }

    private func report(
        backend: InferenceBackend,
        path: String,
        version: String?,
        interpreter: String?,
        checkedAt: Date,
        issues: [RuntimeDoctorIssue]
    ) -> RuntimeDoctorReport {
        RuntimeDoctorReport(
            backend: backend,
            executablePath: path,
            version: version,
            interpreterPath: interpreter,
            issues: issues,
            checkedAt: checkedAt
        )
    }

    private func issue(
        backend: InferenceBackend,
        kind: RuntimeDoctorIssueKind,
        severity: RuntimeDoctorSeverity,
        title: String,
        detail: String,
        command: String?
    ) -> RuntimeDoctorIssue {
        RuntimeDoctorIssue(
            id: "\(backend.rawValue)-\(kind.rawValue)",
            backend: backend,
            kind: kind,
            severity: severity,
            title: title,
            detail: detail,
            commandPreview: command
        )
    }

    private func processOutput(_ result: ShortLivedProcessResult?) -> String? {
        guard let result else { return nil }
        var data = result.standardOutput
        if !result.standardError.isEmpty {
            data.append(Data("\n".utf8))
            data.append(result.standardError)
        }
        return String(data: data, encoding: .utf8)
    }

    private func firstUsefulLine(_ text: String?) -> String? {
        text?.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty && !$0.lowercased().hasPrefix("usage:") }
    }

    private func interpreterPath(for executablePath: String) -> String? {
        guard let handle = FileHandle(forReadingAtPath: executablePath) else { return nil }
        defer { try? handle.close() }
        guard let data = try? handle.read(upToCount: 512),
              let text = String(data: data, encoding: .utf8),
              text.hasPrefix("#!") else {
            return nil
        }
        return text.split(whereSeparator: \.isNewline).first?
            .dropFirst(2)
            .split(separator: " ")
            .first
            .map(String.init)
    }

    private func binaryArchitecture(for executablePath: String) -> String? {
        guard let handle = FileHandle(forReadingAtPath: executablePath) else { return nil }
        defer { try? handle.close() }
        guard let data = try? handle.read(upToCount: 8), data.count >= 8 else { return nil }
        let bytes = [UInt8](data)
        guard bytes[0...3].elementsEqual([0xCF, 0xFA, 0xED, 0xFE]) else { return nil }
        let cpuType = UInt32(bytes[4])
            | UInt32(bytes[5]) << 8
            | UInt32(bytes[6]) << 16
            | UInt32(bytes[7]) << 24
        if cpuType == 0x0100000C { return "arm64" }
        if cpuType == 0x01000007 { return "x86_64" }
        return "unknown"
    }

    private func shellQuote(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }
}

nonisolated protocol ModelMetadataInspecting: Sendable {
    func inspect(model: ModelConfig) async -> ModelMetadataReport
}

actor ModelMetadataInspectionService: ModelMetadataInspecting {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func inspect(model: ModelConfig) async -> ModelMetadataReport {
        let now = Date()
        guard let rawPath = ModelAvailabilityPathFormatter.localPathCandidate(for: model) else {
            return ModelMetadataReport(
                profileID: model.id,
                modelID: model.modelID,
                localPath: nil,
                status: .externalIdentifier,
                modelType: nil,
                architectures: [],
                quantization: nil,
                contextLength: nil,
                vocabularySize: nil,
                hasTokenizer: false,
                hasChatTemplate: false,
                reasoningCandidate: false,
                toolCallingCandidate: false,
                weightFileCount: 0,
                shardCount: nil,
                totalWeightBytes: nil,
                warnings: [],
                checkedAt: now
            )
        }
        let path = URL(fileURLWithPath: rawPath).standardizedFileURL.path
        var isDirectory = ObjCBool(false)
        guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return unavailable(model: model, path: path, status: .unavailable, warning: "The registered local model directory is missing.", checkedAt: now)
        }

        let root = URL(fileURLWithPath: path, isDirectory: true)
        let config = jsonObject(at: root.appendingPathComponent("config.json"))
        let tokenizerConfig = jsonObject(at: root.appendingPathComponent("tokenizer_config.json"))
        let tokenizer = jsonObject(at: root.appendingPathComponent("tokenizer.json"))
        let index = jsonObject(at: root.appendingPathComponent("model.safetensors.index.json"))
        let files = (try? fileManager.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        let weights = files.filter { $0.pathExtension.lowercased() == "safetensors" }
        let totalWeightBytes = weights.reduce(UInt64(0)) { total, url in
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            return total + UInt64(max(size, 0))
        }
        let weightMap = index?["weight_map"] as? [String: Any]
        let referencedShards = Set(weightMap?.values.compactMap { $0 as? String } ?? [])
        let modelType = config?["model_type"] as? String
        let architectures = config?["architectures"] as? [String] ?? []
        let quantizationObject = config?["quantization_config"] as? [String: Any]
        let quantization = (quantizationObject?["quant_method"] as? String)
            ?? (quantizationObject?["format"] as? String)
            ?? model.quantization.nilIfBlank
        let contextLength = integer(config?["max_position_embeddings"])
            ?? integer(config?["max_seq_len"])
            ?? integer(config?["n_positions"])
        let vocabularySize = integer(config?["vocab_size"])
        let tokenizerExists = tokenizer != nil
            || tokenizerConfig != nil
            || fileManager.fileExists(atPath: root.appendingPathComponent("tokenizer.model").path)
        let chatTemplate = (tokenizerConfig?["chat_template"] as? String)
            ?? (tokenizer?["chat_template"] as? String)
        let normalizedSignals = ([modelType] + architectures + [chatTemplate])
            .compactMap { $0?.lowercased() }
            .joined(separator: " ")
        let reasoningCandidate = normalizedSignals.contains("reason")
            || normalizedSignals.contains("think")
            || normalizedSignals.contains("qwen3")
        let toolCallingCandidate = normalizedSignals.contains("tool")
            || normalizedSignals.contains("function")
        var warnings: [String] = []
        if config == nil { warnings.append("config.json could not be decoded.") }
        if !tokenizerExists { warnings.append("Tokenizer data was not detected.") }
        if weights.isEmpty && referencedShards.isEmpty { warnings.append("Safetensors weights were not detected.") }
        if !referencedShards.isEmpty {
            let missingShards = referencedShards.filter {
                !fileManager.fileExists(atPath: root.appendingPathComponent($0).path)
            }
            if !missingShards.isEmpty {
                warnings.append("The weight index references \(missingShards.count) missing shard file(s).")
            }
        }
        let status: ModelMetadataStatus
        if config == nil || !tokenizerExists || (weights.isEmpty && referencedShards.isEmpty) {
            status = .incomplete
        } else if warnings.isEmpty {
            status = .compatibleCandidate
        } else {
            status = .review
        }
        return ModelMetadataReport(
            profileID: model.id,
            modelID: model.modelID,
            localPath: path,
            status: status,
            modelType: modelType,
            architectures: architectures,
            quantization: quantization,
            contextLength: contextLength,
            vocabularySize: vocabularySize,
            hasTokenizer: tokenizerExists,
            hasChatTemplate: chatTemplate?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false,
            reasoningCandidate: reasoningCandidate,
            toolCallingCandidate: toolCallingCandidate,
            weightFileCount: weights.count,
            shardCount: referencedShards.isEmpty ? nil : referencedShards.count,
            totalWeightBytes: totalWeightBytes > 0 ? totalWeightBytes : nil,
            warnings: warnings,
            checkedAt: now
        )
    }

    private func unavailable(
        model: ModelConfig,
        path: String,
        status: ModelMetadataStatus,
        warning: String,
        checkedAt: Date
    ) -> ModelMetadataReport {
        ModelMetadataReport(
            profileID: model.id,
            modelID: model.modelID,
            localPath: path,
            status: status,
            modelType: nil,
            architectures: [],
            quantization: nil,
            contextLength: nil,
            vocabularySize: nil,
            hasTokenizer: false,
            hasChatTemplate: false,
            reasoningCandidate: false,
            toolCallingCandidate: false,
            weightFileCount: 0,
            shardCount: nil,
            totalWeightBytes: nil,
            warnings: [warning],
            checkedAt: checkedAt
        )
    }

    private func jsonObject(at url: URL) -> [String: Any]? {
        guard let data = try? Data(contentsOf: url),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return object
    }

    private func integer(_ value: Any?) -> Int? {
        if let value = value as? Int { return value }
        if let value = value as? NSNumber { return value.intValue }
        if let value = value as? String { return Int(value) }
        return nil
    }
}

nonisolated struct CapacityPlanningService: Sendable {
    func assess(
        plan: LaunchPlanDefinition,
        models: [ModelConfig],
        estimatedGigabytesByProfileID: [String: Double],
        runningProfileIDs: Set<String>,
        managedMemoryGigabytes: Double,
        systemMemory: SystemMemorySnapshot
    ) -> CapacityPlanAssessment {
        let modelByID = Dictionary(uniqueKeysWithValues: models.map { ($0.id, $0) })
        let items = plan.steps.compactMap { step -> CapacityPlanItem? in
            guard let model = modelByID[step.profileID] else { return nil }
            return CapacityPlanItem(
                profileID: model.id,
                displayName: model.displayName,
                estimatedGigabytes: estimatedGigabytesByProfileID[model.id],
                isAlreadyRunning: runningProfileIDs.contains(model.id)
            )
        }
        let candidates = items.filter { !$0.isAlreadyRunning }
        let knownCandidate = candidates.compactMap(\.estimatedGigabytes).reduce(0, +)
        let allKnown = candidates.allSatisfy { $0.estimatedGigabytes != nil }
        let projected = allKnown ? managedMemoryGigabytes + knownCandidate : nil
        let projectedAvailable = systemMemory.availableGigabytes.map { $0 - knownCandidate }
        let reserve = max(systemMemory.totalGigabytes * 0.15, 4)
        let emergency = max(systemMemory.totalGigabytes * 0.05, 2)
        let level: CapacityAssessmentLevel
        if candidates.isEmpty {
            level = .safe
        } else if !allKnown || projectedAvailable == nil {
            level = .unavailable
        } else if projectedAvailable! <= emergency {
            level = .critical
        } else if projectedAvailable! <= reserve {
            level = .caution
        } else {
            level = .safe
        }
        let recommendedOrder = candidates.sorted {
            ($0.estimatedGigabytes ?? .greatestFiniteMagnitude)
                < ($1.estimatedGigabytes ?? .greatestFiniteMagnitude)
        }.map(\.profileID)
        let message: String
        switch level {
        case .safe:
            message = "The launch plan fits within the current conservative memory reserve."
        case .caution:
            message = "The launch plan approaches the conservative system-memory reserve."
        case .critical:
            message = "The launch plan is projected to cross the emergency memory floor."
        case .unavailable:
            message = "One or more model sizes or current memory values are unavailable."
        }
        return CapacityPlanAssessment(
            level: level,
            items: items,
            currentManagedGigabytes: managedMemoryGigabytes,
            candidateGigabytes: allKnown ? knownCandidate : nil,
            projectedManagedGigabytes: projected,
            availableGigabytes: systemMemory.availableGigabytes,
            recommendedOrder: recommendedOrder,
            message: message
        )
    }
}

nonisolated struct SupportBundleService: Sendable {
    func makeReport(
        appVersion: String,
        platform: PlatformCompatibilityReport?,
        runtimeReports: [RuntimeDoctorReport],
        modelMetadata: ModelMetadataReport?,
        evidence: [EvidenceFreshnessItem],
        stability: LaunchStabilityReport?,
        capacity: CapacityPlanAssessment?,
        launchDiagnosis: LaunchFailureDiagnosis?,
        operationalHistory: [RuntimeEvent]
    ) -> SupportBundleReport {
        let now = Date()
        var lines = [
            "MLX Server Manager Support Bundle",
            "Generated: \(ISO8601DateFormatter().string(from: now))",
            "App version: \(appVersion)",
            "Direct Mode: enabled",
            ""
        ]
        if let platform {
            lines.append("Platform: macOS \(platform.currentVersion), \(platform.architecture), minimum \(platform.minimumSupportedVersion)")
        }
        lines.append("")
        lines.append("Runtime Doctor")
        for report in runtimeReports {
            lines.append("- \(report.backend.rawValue): \(report.status.rawValue), version=\(report.version ?? "unknown"), executable=\(URL(fileURLWithPath: report.executablePath).lastPathComponent)")
            for issue in report.issues {
                lines.append("  - \(issue.severity.rawValue): \(sanitize(issue.title))")
            }
        }
        lines.append("")
        lines.append("Evidence Freshness")
        for item in evidence {
            lines.append("- \(item.domain.rawValue): \(item.status.rawValue)")
        }
        if let modelMetadata {
            lines.append("")
            lines.append("Model Metadata")
            lines.append("- model_id: \(sanitize(modelMetadata.modelID))")
            lines.append("- status: \(modelMetadata.status.rawValue)")
            lines.append("- model_type: \(modelMetadata.modelType ?? "unknown")")
            lines.append("- local_folder: \(modelMetadata.localPath.map { URL(fileURLWithPath: $0).lastPathComponent } ?? "external")")
            lines.append("- weights: \(modelMetadata.weightFileCount)")
        }
        if let stability {
            lines.append("")
            lines.append("Launch Stability: \(stability.status.rawValue), samples=\(stability.samples.count)")
        }
        if let capacity {
            lines.append("")
            lines.append("Capacity: \(capacity.level.rawValue), profiles=\(capacity.items.count)")
        }
        if let launchDiagnosis {
            lines.append("")
            lines.append("Latest Launch Diagnosis")
            lines.append(launchDiagnosis.copyText(language: .english))
        }
        lines.append("")
        lines.append("Operational History")
        for event in operationalHistory.suffix(30) {
            lines.append("- \(event.category): \(sanitize(event.message))")
        }
        return SupportBundleReport(
            generatedAt: now,
            text: redact(lines.joined(separator: "\n"))
        )
    }

    private func sanitize(_ value: String) -> String {
        value.replacingOccurrences(of: NSHomeDirectory(), with: "~")
    }

    private func redact(_ value: String) -> String {
        var result = value
        let replacements = [
            (#"(?i)(authorization\s*:\s*bearer\s+)[^\s]+"#, "$1[REDACTED]"),
            (#"(?i)(api[_-]?key\s*[=:]\s*)[^\s]+"#, "$1[REDACTED]"),
            (#"(?i)(token\s*[=:]\s*)[^\s]+"#, "$1[REDACTED]"),
            (#"hf_[A-Za-z0-9]{12,}"#, "[REDACTED]")
        ]
        for (pattern, template) in replacements {
            guard let expression = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(result.startIndex..<result.endIndex, in: result)
            result = expression.stringByReplacingMatches(
                in: result,
                range: range,
                withTemplate: template
            )
        }
        return result
    }
}

private nonisolated extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
