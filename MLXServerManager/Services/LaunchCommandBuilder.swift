import Foundation

struct LaunchCommandBuilder {
    static func command(executablePath: String, model: ModelConfig) -> String {
        let executable = executablePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "mlx_lm.server"
            : executablePath
        var parts = [
            shellQuoted(executable),
            "--model", shellQuoted(model.modelID),
            "--host", shellQuoted(model.host),
            "--port", String(model.serverPort)
        ]
        if model.enableThinking {
            parts.append("--enable-thinking")
        }
        if let rawExtraArgs = model.advancedLaunchOptions?.rawExtraArgs?.trimmingCharacters(in: .whitespacesAndNewlines),
           !rawExtraArgs.isEmpty {
            parts.append(rawExtraArgs)
        }
        return parts.joined(separator: " ")
    }

    static func shellQuoted(_ value: String) -> String {
        guard !value.isEmpty else { return "''" }
        let escaped = value.replacingOccurrences(of: "'", with: "'\\''")
        return "'\(escaped)'"
    }
}
