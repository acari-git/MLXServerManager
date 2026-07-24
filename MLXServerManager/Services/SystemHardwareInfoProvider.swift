import Foundation

nonisolated protocol SystemHardwareInfoProviding: Sendable {
    func loadHardwareInfo() async -> [String: String]
}

nonisolated final class SystemHardwareInfoProvider: SystemHardwareInfoProviding, @unchecked Sendable {
    private let executablePath: String
    private let arguments: [String]
    private let timeout: TimeInterval

    init(
        executablePath: String = "/usr/sbin/system_profiler",
        arguments: [String] = ["SPHardwareDataType", "SPDisplaysDataType"],
        timeout: TimeInterval = 15
    ) {
        self.executablePath = executablePath
        self.arguments = arguments
        self.timeout = timeout
    }

    func loadHardwareInfo() async -> [String: String] {
        let executablePath = executablePath
        let arguments = arguments
        let timeout = timeout
        guard let result = await ShortLivedProcessRunner.runAsync(
            executablePath: executablePath,
            arguments: arguments,
            timeout: timeout
        ),
        !result.timedOut,
        !result.cancelled,
        result.terminationStatus == 0,
        let output = String(data: result.standardOutput, encoding: .utf8) else {
            return [:]
        }

        return Self.parseSystemProfilerHardwareInfo(output)
    }

    static func parseSystemProfilerHardwareInfo(_ output: String) -> [String: String] {
        var result: [String: String] = [:]
        var isHardwareSection = false
        var isDisplaysSection = false
        var didCaptureCPUCores = false
        var didCaptureGPUCores = false

        for line in output.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed == "Hardware:" {
                isHardwareSection = true
                isDisplaysSection = false
                continue
            }
            if trimmed == "Graphics/Displays:" {
                isHardwareSection = false
                isDisplaysSection = true
                continue
            }
            guard let separatorIndex = trimmed.firstIndex(of: ":") else { continue }
            let key = String(trimmed[..<separatorIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
            let value = String(trimmed[trimmed.index(after: separatorIndex)...]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty, !value.isEmpty else { continue }

            if isHardwareSection {
                if ["Model Name", "Model Identifier", "Chip", "Memory"].contains(key) {
                    result[key] = value
                } else if key == "Total Number of Cores", !didCaptureCPUCores {
                    result[key] = value
                    didCaptureCPUCores = true
                }
            } else if isDisplaysSection, key == "Total Number of Cores", !didCaptureGPUCores {
                result["GPU Cores"] = value
                didCaptureGPUCores = true
            }
        }

        return result
    }
}
