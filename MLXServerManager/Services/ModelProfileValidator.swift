import Foundation

nonisolated enum ModelProfileValidationResult: Equatable {
    case valid(ModelConfig)
    case invalid(String)
}

nonisolated enum AdvancedLaunchOptionsValidationResult: Equatable {
    case valid(AdvancedLaunchOptions?)
    case invalid(String)
}

nonisolated struct ModelProfileValidator {
    func validateNewProfile(
        _ draft: ModelProfileDraft,
        existingModels: [ModelConfig]
    ) -> ModelProfileValidationResult {
        let fields = normalizedFields(from: draft)

        guard !fields.modelID.isEmpty else {
            return .invalid("Model ID is required.")
        }

        guard !fields.host.isEmpty else {
            return .invalid("Host is required.")
        }

        guard let port = fields.port else {
            return .invalid("Port must be between 1 and 65535.")
        }

        guard !existingModels.contains(where: { $0.modelID == fields.modelID }) else {
            return .invalid("A model profile with this Model ID already exists.")
        }

        let advancedLaunchOptions: AdvancedLaunchOptions?
        switch validateAdvancedLaunchOptions(draft.advancedLaunchOptions, backend: draft.backend) {
        case let .valid(options):
            advancedLaunchOptions = options
        case let .invalid(message):
            return .invalid(message)
        }

        let localName = fields.modelID.split(separator: "/").last.map(String.init) ?? fields.modelID
        return .valid(
            ModelConfig(
                modelID: fields.modelID,
                displayName: fields.displayName.isEmpty ? fields.modelID : fields.displayName,
                family: "Custom",
                quantization: "User configured",
                localName: localName,
                host: fields.host,
                serverPort: port,
                enableThinking: draft.enableThinking,
                notes: fields.notes,
                advancedLaunchOptions: advancedLaunchOptions,
                backend: draft.backend
            )
        )
    }

    func validateProfileEdit(
        _ draft: ModelProfileDraft,
        existingModel: ModelConfig,
        isRunning: Bool,
        language: AppLanguage
    ) -> ModelProfileValidationResult {
        let fields = normalizedFields(from: draft)

        guard !fields.modelID.isEmpty else {
            return .invalid("Model ID is required.")
        }

        guard !fields.host.isEmpty else {
            return .invalid("Host is required.")
        }

        guard let port = fields.port else {
            return .invalid("Port must be between 1 and 65535.")
        }

        let advancedLaunchOptions: AdvancedLaunchOptions?
        switch validateAdvancedLaunchOptions(draft.advancedLaunchOptions, backend: draft.backend) {
        case let .valid(options):
            advancedLaunchOptions = options
        case let .invalid(message):
            return .invalid(message)
        }

        let changesRuntimeTarget = fields.modelID != existingModel.modelID
            || draft.backend != existingModel.resolvedBackend
            || fields.host != existingModel.host
            || port != existingModel.serverPort
            || advancedLaunchOptions != existingModel.advancedLaunchOptions?.normalized()

        if isRunning && changesRuntimeTarget {
            return .invalid(AppLocalization(language: language).text(
                english: "Stop this model before changing its model path, backend, host, port, or advanced launch options.",
                japanese: "このモデルを停止してから、モデルパス、バックエンド、Host、Port、詳細起動オプションを変更してください。"
            ))
        }

        var updatedModel = existingModel
        updatedModel.displayName = fields.displayName.isEmpty ? fields.modelID : fields.displayName
        updatedModel.modelID = fields.modelID
        updatedModel.host = fields.host
        updatedModel.serverPort = port
        updatedModel.enableThinking = draft.enableThinking
        updatedModel.notes = fields.notes
        updatedModel.advancedLaunchOptions = advancedLaunchOptions
        updatedModel.backend = draft.backend
        return .valid(updatedModel)
    }

    func validateAdvancedLaunchOptions(
        _ options: AdvancedLaunchOptions,
        backend: InferenceBackend
    ) -> AdvancedLaunchOptionsValidationResult {
        guard let normalizedOptions = options.normalized() else {
            return .valid(nil)
        }

        let boundedDoubleFields: [(String, String?)] = [
            ("Default Temperature", normalizedOptions.defaultTemperature),
            ("Default Top P", normalizedOptions.defaultTopP),
            ("Default Min P", normalizedOptions.defaultMinP)
        ]

        for (label, value) in boundedDoubleFields {
            guard let value else { continue }
            guard let doubleValue = Double(value), (0...1).contains(doubleValue) else {
                return .invalid("\(label) must be between 0 and 1.")
            }
        }

        let positiveIntegerFields: [(String, String?)] = [
            ("Default Top K", normalizedOptions.defaultTopK),
            ("Default Max Tokens", normalizedOptions.defaultMaxTokens),
            ("Decode Concurrency", normalizedOptions.decodeConcurrency),
            ("Prompt Concurrency", normalizedOptions.promptConcurrency),
            ("Prefill Step Size", normalizedOptions.prefillStepSize),
            ("Prompt Cache Size", normalizedOptions.promptCacheSize),
            ("Prompt Cache Bytes", normalizedOptions.promptCacheBytes)
        ]

        for (label, value) in positiveIntegerFields {
            guard let value else { continue }
            guard let integerValue = Int(value), integerValue > 0 else {
                return .invalid("\(label) must be a positive integer.")
            }
        }

        if let chatTemplateArgs = normalizedOptions.chatTemplateArgs {
            guard backend == .mlxLM else {
                return .invalid("Chat Template Args are supported by mlx-lm profiles only.")
            }
            guard let data = chatTemplateArgs.data(using: .utf8),
                  (try? JSONSerialization.jsonObject(with: data)) != nil else {
                return .invalid("Chat Template Args must be valid JSON.")
            }
        }

        if backend == .rapidMLX,
           let logLevel = normalizedOptions.logLevel,
           !["DEBUG", "INFO", "WARNING", "ERROR"].contains(logLevel.uppercased()) {
            return .invalid("Rapid-MLX Log Level must be DEBUG, INFO, WARNING, or ERROR.")
        }

        if let rawExtraArgs = normalizedOptions.rawExtraArgs {
            do {
                let parsedArguments = try ShellArgumentParser.parse(rawExtraArgs)
                if let forbiddenFlag = ManagedLaunchArgumentPolicy.firstForbiddenFlag(
                    in: parsedArguments,
                    backend: backend
                ) {
                    return .invalid("Raw Extra Args must not override the managed argument \(forbiddenFlag).")
                }
            } catch {
                return .invalid(error.localizedDescription)
            }
        }

        return .valid(normalizedOptions)
    }

    private func normalizedFields(from draft: ModelProfileDraft) -> NormalizedProfileFields {
        let portText = draft.serverPortText.trimmingCharacters(in: .whitespacesAndNewlines)
        let port = Int(portText).flatMap { (1...65_535).contains($0) ? $0 : nil }
        return NormalizedProfileFields(
            modelID: draft.modelID.trimmingCharacters(in: .whitespacesAndNewlines),
            displayName: draft.displayName.trimmingCharacters(in: .whitespacesAndNewlines),
            host: draft.host.trimmingCharacters(in: .whitespacesAndNewlines),
            port: port,
            notes: draft.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
}

nonisolated private struct NormalizedProfileFields {
    let modelID: String
    let displayName: String
    let host: String
    let port: Int?
    let notes: String
}
