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
            notes: "Primary Direct Mode model profile confirmed for local MLX use."
        )
    ]
}

struct ModelProfileDraft: Equatable {
    var originalModelID: String
    var displayName: String
    var modelID: String
    var host: String
    var serverPortText: String
    var enableThinking: Bool
    var notes: String

    static let empty = ModelProfileDraft(
        originalModelID: "",
        displayName: "",
        modelID: "",
        host: "",
        serverPortText: "",
        enableThinking: false,
        notes: ""
    )

    init(model: ModelConfig) {
        self.originalModelID = model.modelID
        self.displayName = model.displayName
        self.modelID = model.modelID
        self.host = model.host
        self.serverPortText = String(model.serverPort)
        self.enableThinking = model.enableThinking
        self.notes = model.notes
    }

    private init(
        originalModelID: String,
        displayName: String,
        modelID: String,
        host: String,
        serverPortText: String,
        enableThinking: Bool,
        notes: String
    ) {
        self.originalModelID = originalModelID
        self.displayName = displayName
        self.modelID = modelID
        self.host = host
        self.serverPortText = serverPortText
        self.enableThinking = enableThinking
        self.notes = notes
    }
}
