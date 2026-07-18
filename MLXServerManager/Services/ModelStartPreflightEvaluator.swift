import Foundation

nonisolated struct ManagedModelEndpointConflict: Equatable {
    let modelDisplayName: String
    let processIdentifier: Int32
}

nonisolated enum ModelStartPreflightIssue: Equatable {
    case missingExecutablePath(backend: InferenceBackend)
    case unusableExecutable(backend: InferenceBackend, path: String)
    case missingModelPath(path: String)
    case managedEndpointConflict(
        host: String,
        port: Int,
        modelDisplayName: String,
        processIdentifier: Int32
    )
    case portUnavailable(PortCheckResult)

    func blockingMessage(language: AppLanguage) -> String {
        let strings = AppLocalization(language: language)
        switch self {
        case .missingExecutablePath:
            return strings.text(
                english: "Missing executable path",
                japanese: "実行ファイルパスが未設定"
            )
        case .unusableExecutable:
            return "Missing or not executable"
        case .missingModelPath:
            return "Missing local path"
        case let .managedEndpointConflict(_, _, modelDisplayName, processIdentifier):
            return strings.text(
                english: "Server port: Used by loaded model \(modelDisplayName) (pid \(processIdentifier))",
                japanese: "サーバーポート: ロード済みモデル \(modelDisplayName) が使用中です (pid \(processIdentifier))"
            )
        case let .portUnavailable(result):
            return "Server port: \(Self.portMessage(for: result, language: language))"
        }
    }

    func launchMessage(language: AppLanguage) -> String {
        let strings = AppLocalization(language: language)
        switch self {
        case let .missingExecutablePath(backend):
            return "\(backend.localizedTitle(language: language)) executable path is not configured. Set it in Settings before starting."
        case let .unusableExecutable(backend, path):
            return "\(backend.localizedTitle(language: language)) executable was not found or is not executable: \(ModelAvailabilityPathFormatter.compact(path: path))."
        case let .missingModelPath(path):
            return "Model path is missing: \(ModelAvailabilityPathFormatter.compact(path: path))."
        case let .managedEndpointConflict(host, port, modelDisplayName, processIdentifier):
            return strings.text(
                english: "The endpoint \(host):\(port) is already used by loaded model \(modelDisplayName) (pid \(processIdentifier)). Choose another port.",
                japanese: "\(host):\(port) はロード済みモデル \(modelDisplayName) (pid \(processIdentifier)) が使用中です。別のポートを選択してください。"
            )
        case let .portUnavailable(result):
            return "Server port: \(Self.portMessage(for: result, language: language))"
        }
    }

    var isManagedEndpointConflict: Bool {
        if case .managedEndpointConflict = self {
            return true
        }
        return false
    }

    private static func portMessage(for result: PortCheckResult, language: AppLanguage) -> String {
        let strings = AppLocalization(language: language)
        switch result {
        case .available:
            return strings.text(english: "Port available", japanese: "利用可能")
        case let .busy(_, _, processIdentifier):
            if let processIdentifier {
                return strings.text(
                    english: "Busy (PID: \(processIdentifier))",
                    japanese: "使用中（PID: \(processIdentifier)）"
                )
            }
            return strings.text(english: "Busy", japanese: "使用中")
        case let .invalidInput(message):
            return strings.text(english: "Invalid: \(message)", japanese: "無効: \(message)")
        case let .failed(_, _, message):
            return strings.text(
                english: "Check failed: \(message)",
                japanese: "確認失敗: \(message)"
            )
        }
    }
}

nonisolated struct ModelStartPreflightEvaluator {
    func evaluate(
        model: ModelConfig,
        executablePath: String,
        managedEndpointConflict: ManagedModelEndpointConflict?,
        portCheckResult: PortCheckResult
    ) -> ModelStartPreflightIssue? {
        if let issue = evaluateStatic(
            model: model,
            executablePath: executablePath,
            managedEndpointConflict: managedEndpointConflict
        ) {
            return issue
        }

        return evaluatePort(portCheckResult)
    }

    func evaluateStatic(
        model: ModelConfig,
        executablePath: String,
        managedEndpointConflict: ManagedModelEndpointConflict?
    ) -> ModelStartPreflightIssue? {
        if let issue = evaluateLocal(model: model, executablePath: executablePath) {
            return issue
        }
        return evaluateManagedEndpoint(
            model: model,
            managedEndpointConflict: managedEndpointConflict
        )
    }

    func evaluateLocal(
        model: ModelConfig,
        executablePath: String
    ) -> ModelStartPreflightIssue? {
        let normalizedExecutablePath = executablePath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedExecutablePath.isEmpty else {
            return .missingExecutablePath(backend: model.resolvedBackend)
        }
        guard FileManager.default.isExecutableFile(atPath: normalizedExecutablePath) else {
            return .unusableExecutable(
                backend: model.resolvedBackend,
                path: normalizedExecutablePath
            )
        }

        if let localPath = ModelAvailabilityPathFormatter.localPathCandidate(for: model) {
            var isDirectory = ObjCBool(false)
            guard FileManager.default.fileExists(atPath: localPath, isDirectory: &isDirectory),
                  isDirectory.boolValue else {
                return .missingModelPath(path: localPath)
            }
        }
        return nil
    }

    func evaluateManagedEndpoint(
        model: ModelConfig,
        managedEndpointConflict: ManagedModelEndpointConflict?
    ) -> ModelStartPreflightIssue? {
        guard let managedEndpointConflict else {
            return nil
        }
        return .managedEndpointConflict(
            host: model.host,
            port: model.serverPort,
            modelDisplayName: managedEndpointConflict.modelDisplayName,
            processIdentifier: managedEndpointConflict.processIdentifier
        )
    }

    func evaluatePort(_ result: PortCheckResult) -> ModelStartPreflightIssue? {
        guard case .available = result else {
            return .portUnavailable(result)
        }
        return nil
    }
}
