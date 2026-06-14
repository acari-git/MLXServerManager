import Foundation

struct ModelConfig: Codable, Identifiable, Hashable {
    var modelID: String
    var displayName: String
    var family: String
    var quantization: String
    var localName: String
    var host: String
    var serverPort: Int
    var enableThinking: Bool
    var notes: String
    var advancedLaunchOptions: AdvancedLaunchOptions?

    var id: String {
        modelID
    }

    var contextWindow: String {
        "Configured by mlx_lm.server"
    }

    static let defaults: [ModelConfig] = [
        ModelConfig(
            modelID: "unsloth/Qwen3.6-35B-A3B-UD-MLX-4bit",
            displayName: "Qwen3.6 35B A3B UD 4-bit",
            family: "Qwen3.6",
            quantization: "4-bit",
            localName: "Qwen3.6-35B-A3B-UD-MLX-4bit",
            host: "127.0.0.1",
            serverPort: 8080,
            enableThinking: true,
            notes: "Primary Direct Mode model profile confirmed for local MLX use.",
            advancedLaunchOptions: nil
        )
    ]
}

struct AdvancedLaunchOptions: Codable, Hashable {
    var rawExtraArgs: String? = nil
    var chatTemplateArgs: String? = nil
    var defaultTemperature: String? = nil
    var defaultTopP: String? = nil
    var defaultTopK: String? = nil
    var defaultMinP: String? = nil
    var defaultMaxTokens: String? = nil
    var allowedOrigins: String? = nil
    var logLevel: String? = nil
    var decodeConcurrency: String? = nil
    var promptConcurrency: String? = nil
    var prefillStepSize: String? = nil
    var promptCacheSize: String? = nil
    var promptCacheBytes: String? = nil

    static let empty = AdvancedLaunchOptions()

    nonisolated var isEmpty: Bool {
        !hasAnyValue
    }

    nonisolated func normalized() -> AdvancedLaunchOptions? {
        let normalizedOptions = AdvancedLaunchOptions(
            rawExtraArgs: Self.clean(rawExtraArgs),
            chatTemplateArgs: Self.clean(chatTemplateArgs),
            defaultTemperature: Self.clean(defaultTemperature),
            defaultTopP: Self.clean(defaultTopP),
            defaultTopK: Self.clean(defaultTopK),
            defaultMinP: Self.clean(defaultMinP),
            defaultMaxTokens: Self.clean(defaultMaxTokens),
            allowedOrigins: Self.clean(allowedOrigins),
            logLevel: Self.clean(logLevel),
            decodeConcurrency: Self.clean(decodeConcurrency),
            promptConcurrency: Self.clean(promptConcurrency),
            prefillStepSize: Self.clean(prefillStepSize),
            promptCacheSize: Self.clean(promptCacheSize),
            promptCacheBytes: Self.clean(promptCacheBytes)
        )

        return normalizedOptions.hasAnyValue ? normalizedOptions : nil
    }

    nonisolated private var hasAnyValue: Bool {
        [
            rawExtraArgs,
            chatTemplateArgs,
            defaultTemperature,
            defaultTopP,
            defaultTopK,
            defaultMinP,
            defaultMaxTokens,
            allowedOrigins,
            logLevel,
            decodeConcurrency,
            promptConcurrency,
            prefillStepSize,
            promptCacheSize,
            promptCacheBytes
        ].contains { value in
            guard let value else {
                return false
            }

            return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    nonisolated private static func clean(_ value: String?) -> String? {
        guard let value else {
            return nil
        }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

struct ModelProfileDraft: Equatable {
    var originalModelID: String
    var displayName: String
    var modelID: String
    var host: String
    var serverPortText: String
    var enableThinking: Bool
    var notes: String
    var advancedLaunchOptions: AdvancedLaunchOptions

    static let empty = ModelProfileDraft(
        originalModelID: "",
        displayName: "",
        modelID: "",
        host: "",
        serverPortText: "",
        enableThinking: false,
        notes: "",
        advancedLaunchOptions: .empty
    )

    static func newProfile(defaultHost: String, defaultPort: Int) -> ModelProfileDraft {
        ModelProfileDraft(
            originalModelID: "",
            displayName: "",
            modelID: "",
            host: defaultHost,
            serverPortText: String(defaultPort),
            enableThinking: false,
            notes: "",
            advancedLaunchOptions: .empty
        )
    }

    init(model: ModelConfig) {
        self.originalModelID = model.modelID
        self.displayName = model.displayName
        self.modelID = model.modelID
        self.host = model.host
        self.serverPortText = String(model.serverPort)
        self.enableThinking = model.enableThinking
        self.notes = model.notes
        self.advancedLaunchOptions = model.advancedLaunchOptions ?? .empty
    }

    private init(
        originalModelID: String,
        displayName: String,
        modelID: String,
        host: String,
        serverPortText: String,
        enableThinking: Bool,
        notes: String,
        advancedLaunchOptions: AdvancedLaunchOptions
    ) {
        self.originalModelID = originalModelID
        self.displayName = displayName
        self.modelID = modelID
        self.host = host
        self.serverPortText = serverPortText
        self.enableThinking = enableThinking
        self.notes = notes
        self.advancedLaunchOptions = advancedLaunchOptions
    }
}
