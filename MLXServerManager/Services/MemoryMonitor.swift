import Foundation

struct MemoryUsageSnapshot: Equatable, Sendable {
    let processIdentifier: Int32
    let rssKilobytes: Int64

    var gigabytes: Double {
        Double(rssKilobytes) / 1_048_576
    }
}

enum MemoryMonitorResult: Equatable, Sendable {
    case usage(MemoryUsageSnapshot)
    case notRunning(processIdentifier: Int32)
    case invalidInput(String)
    case failed(processIdentifier: Int32, message: String)
}

struct MemoryMonitor: Sendable {
    nonisolated init() {}

    nonisolated func currentUsage(processIdentifier: Int32) async -> MemoryMonitorResult {
        guard processIdentifier > 0 else {
            return .invalidInput("Process identifier must be greater than zero.")
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = [
            "-o",
            "rss=",
            "-p",
            String(processIdentifier)
        ]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
        } catch {
            return .failed(
                processIdentifier: processIdentifier,
                message: "Could not run ps for pid \(processIdentifier): \(error.localizedDescription)"
            )
        }

        process.waitUntilExit()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outputData, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let errorOutput = String(data: errorData, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard process.terminationStatus == 0 else {
            let message = errorOutput.isEmpty
                ? "ps exited with status \(process.terminationStatus)"
                : errorOutput
            return .failed(processIdentifier: processIdentifier, message: message)
        }

        guard !output.isEmpty else {
            return .notRunning(processIdentifier: processIdentifier)
        }

        guard let rssKilobytes = Int64(output) else {
            return .failed(
                processIdentifier: processIdentifier,
                message: "Could not parse RSS from ps output: \(output)"
            )
        }

        return .usage(
            MemoryUsageSnapshot(
                processIdentifier: processIdentifier,
                rssKilobytes: rssKilobytes
            )
        )
    }
}
