import Foundation

nonisolated struct MLXLMVersionProvider {
    var fileManager: FileManager = .default
    var timeout: TimeInterval = 2

    func version(executablePath: String) async -> String? {
        let trimmedPath = executablePath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPath.isEmpty,
              fileManager.fileExists(atPath: trimmedPath),
              fileManager.isExecutableFile(atPath: trimmedPath) else {
            return nil
        }

        return await Self.runVersionCommand(executablePath: trimmedPath, timeout: timeout)
    }

    func version(executablePath: String, backend: InferenceBackend) async -> String? {
        await version(executablePath: executablePath)
    }

    nonisolated static func normalizedVersionOutput(_ output: String) -> String? {
        let lines = output
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return lines.first { line in
            let lowercased = line.lowercased()
            guard !lowercased.hasPrefix("usage:"),
                  !lowercased.contains("[--model model]"),
                  !lowercased.contains("optional arguments") else {
                return false
            }
            return line.range(of: #"(?i)(mlx[-_ ]?lm|mlx_lm).*([0-9]+\.[0-9]+)"#, options: .regularExpression) != nil
                || line.range(of: #"(?i)rapid[-_ ]?mlx.*([0-9]+\.[0-9]+)"#, options: .regularExpression) != nil
                || line.range(of: #"^[0-9]+\.[0-9]+(\.[0-9]+)?"#, options: .regularExpression) != nil
        }
    }

    private nonisolated static func runVersionCommand(
        executablePath: String,
        timeout: TimeInterval
    ) async -> String? {
        guard let result = await ShortLivedProcessRunner.runAsync(
            executablePath: executablePath,
            arguments: ["--version"],
            timeout: timeout
        ), !result.timedOut, !result.cancelled else {
            return nil
        }

        var combinedOutput = result.standardOutput
        combinedOutput.append(Data("\n".utf8))
        combinedOutput.append(result.standardError)
        guard let output = String(data: combinedOutput, encoding: .utf8) else {
            return nil
        }
        return normalizedVersionOutput(output)
    }
}
