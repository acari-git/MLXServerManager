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
