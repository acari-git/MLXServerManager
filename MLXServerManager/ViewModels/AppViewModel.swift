import AppKit
import Combine
import Foundation

final class AppViewModel: ObservableObject {
    @Published var selectedModelID: ModelConfig.ID?
    @Published private(set) var runtimeState: ModelRuntimeState = .stopped
    @Published private(set) var logLines: [String] = [
        "[info] MLX Server Manager UI loaded.",
        "[info] Direct Mode selected. No proxy is configured.",
        "[info] Server launch, port checks, and readiness checks are not implemented in Step 2."
    ]

    let models: [ModelConfig] = [
        ModelConfig(
            id: "unsloth/Qwen3.6-35B-A3B-UD-MLX-4bit",
            displayName: "Qwen3.6 35B A3B UD 4-bit",
            family: "Qwen3.6",
            quantization: "4-bit",
            contextWindow: "Configured by mlx_lm.server",
            localName: "Qwen3.6-35B-A3B-UD-MLX-4bit",
            status: .verified,
            notes: "Primary Direct Mode model profile confirmed for local MLX use."
        ),
        ModelConfig(
            id: "mlx-community/Qwen3-14B-4bit",
            displayName: "Qwen3 14B 4-bit",
            family: "Qwen3",
            quantization: "4-bit",
            contextWindow: "Configured by mlx_lm.server",
            localName: "Qwen3-14B-4bit",
            status: .candidate,
            notes: "Medium local model profile reserved for later launch configuration."
        ),
        ModelConfig(
            id: "mlx-community/Qwen3-32B-4bit",
            displayName: "Qwen3 32B 4-bit",
            family: "Qwen3",
            quantization: "4-bit",
            contextWindow: "Configured by mlx_lm.server",
            localName: "Qwen3-32B-4bit",
            status: .candidate,
            notes: "Larger local model profile for future memory monitoring work."
        )
    ]

    private let connectionConfigBuilder = ConnectionConfigBuilder(
        scheme: "http",
        host: "127.0.0.1",
        port: 8080,
        apiBasePath: "/v1",
        apiKeyPlaceholder: "not-required-local"
    )

    init() {
        selectedModelID = models.first?.id
    }

    var selectedModel: ModelConfig? {
        models.first { $0.id == selectedModelID } ?? models.first
    }

    var baseURL: String {
        connectionConfigBuilder.baseURL
    }

    var selectedModelIdentifier: String {
        selectedModel?.id ?? "No model selected"
    }

    var apiKeyPlaceholder: String {
        connectionConfigBuilder.apiKeyPlaceholder
    }

    var copyableConfig: String {
        connectionConfigBuilder.configText(modelID: selectedModelIdentifier)
    }

    var logText: String {
        logLines.joined(separator: "\n")
    }

    func startRequested() {
        appendLog("[ui] Start requested. Server launch is intentionally not implemented in Step 2.")
    }

    func stopRequested() {
        appendLog("[ui] Stop requested. Server termination is intentionally not implemented in Step 2.")
    }

    func restartRequested() {
        appendLog("[ui] Restart requested. Restart wiring is intentionally not implemented in Step 2.")
    }

    func copyBaseURL() {
        copyToPasteboard(baseURL)
        appendLog("[ui] Copied Base URL.")
    }

    func copyModelID() {
        copyToPasteboard(selectedModelIdentifier)
        appendLog("[ui] Copied Model ID.")
    }

    func copyConfig() {
        copyToPasteboard(copyableConfig)
        appendLog("[ui] Copied OpenAI-compatible config.")
    }

    private func appendLog(_ line: String) {
        logLines.append(line)
    }

    private func copyToPasteboard(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }
}

