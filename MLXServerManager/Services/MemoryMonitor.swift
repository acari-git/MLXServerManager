import Foundation

struct MemoryUsageSnapshot: Equatable, Sendable {
    let processIdentifier: Int32
    let rssKilobytes: Int64

    var gigabytes: Double {
        Double(rssKilobytes) / 1_048_576
    }
}

struct SystemMemorySnapshot: Equatable, Sendable {
    let totalBytes: UInt64
    let availableBytes: UInt64?

    var totalGigabytes: Double {
        Double(totalBytes) / 1_073_741_824
    }

    var availableGigabytes: Double? {
        guard let availableBytes else { return nil }
        return Double(availableBytes) / 1_073_741_824
    }

    var usedGigabytes: Double? {
        guard let availableGigabytes else { return nil }
        return max(totalGigabytes - availableGigabytes, 0)
    }
}

struct MemoryBreakdownSnapshot: Equatable, Sendable {
    let processIdentifier: Int32
    let rssKilobytes: Int64
    let system: SystemMemorySnapshot
    let modelEstimateGigabytes: Double?
    let modelEstimateSource: String?
    let updatedAt: Date

    var managedProcessGigabytes: Double {
        Double(rssKilobytes) / 1_048_576
    }

    var modelInProcessGigabytes: Double? {
        guard let modelEstimateGigabytes else { return nil }
        return min(max(modelEstimateGigabytes, 0), managedProcessGigabytes)
    }

    var hasRuntimeEstimate: Bool {
        guard let modelEstimateGigabytes else {
            return false
        }

        return modelEstimateGigabytes < managedProcessGigabytes
    }

    var mlxRuntimeGigabytes: Double? {
        guard hasRuntimeEstimate,
              let modelInProcessGigabytes else {
            return nil
        }

        return max(managedProcessGigabytes - modelInProcessGigabytes, 0)
    }

    var otherProcessesGigabytes: Double? {
        guard let usedGigabytes = system.usedGigabytes else { return nil }
        return max(usedGigabytes - managedProcessGigabytes, 0)
    }
}

enum MemoryMonitorResult: Equatable, Sendable {
    case usage(MemoryUsageSnapshot)
    case notRunning(processIdentifier: Int32)
    case invalidInput(String)
    case failed(processIdentifier: Int32, message: String)
}

enum MemoryBreakdownMonitorResult: Equatable, Sendable {
    case usage(MemoryBreakdownSnapshot)
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

    nonisolated func currentBreakdown(
        processIdentifier: Int32,
        modelEstimateGigabytes: Double?,
        modelEstimateSource: String?
    ) async -> MemoryBreakdownMonitorResult {
        let usageResult = await currentUsage(processIdentifier: processIdentifier)

        switch usageResult {
        case let .usage(snapshot):
            return .usage(
                MemoryBreakdownSnapshot(
                    processIdentifier: processIdentifier,
                    rssKilobytes: snapshot.rssKilobytes,
                    system: currentSystemMemory(),
                    modelEstimateGigabytes: modelEstimateGigabytes,
                    modelEstimateSource: modelEstimateSource,
                    updatedAt: Date()
                )
            )
        case let .notRunning(processIdentifier):
            return .notRunning(processIdentifier: processIdentifier)
        case let .invalidInput(message):
            return .invalidInput(message)
        case let .failed(processIdentifier, message):
            return .failed(processIdentifier: processIdentifier, message: message)
        }
    }

    nonisolated func estimatedModelStorageGigabytes(modelDirectoryPath: String?) -> Double? {
        guard let modelDirectoryPath,
              !modelDirectoryPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        var isDirectory = ObjCBool(false)
        guard FileManager.default.fileExists(atPath: modelDirectoryPath, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return nil
        }

        let weightFileExtensions: Set<String> = [
            "safetensors",
            "bin",
            "gguf",
            "npz"
        ]

        guard let enumerator = FileManager.default.enumerator(
            at: URL(fileURLWithPath: modelDirectoryPath),
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        var totalBytes: UInt64 = 0

        for case let fileURL as URL in enumerator {
            guard weightFileExtensions.contains(fileURL.pathExtension.lowercased()) else {
                continue
            }

            do {
                let values = try fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
                guard values.isRegularFile == true,
                      let fileSize = values.fileSize,
                      fileSize > 0 else {
                    continue
                }

                totalBytes += UInt64(fileSize)
            } catch {
                continue
            }
        }

        guard totalBytes > 0 else {
            return nil
        }

        return Double(totalBytes) / 1_073_741_824
    }

    nonisolated private func currentSystemMemory() -> SystemMemorySnapshot {
        let totalBytes = ProcessInfo.processInfo.physicalMemory
        guard let availableBytes = currentAvailableMemoryBytes(totalBytes: totalBytes) else {
            return SystemMemorySnapshot(totalBytes: totalBytes, availableBytes: nil)
        }

        return SystemMemorySnapshot(
            totalBytes: totalBytes,
            availableBytes: min(availableBytes, totalBytes)
        )
    }

    nonisolated private func currentAvailableMemoryBytes(totalBytes: UInt64) -> UInt64? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/vm_stat")

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            return nil
        }

        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            return nil
        }

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: outputData, encoding: .utf8) else {
            return nil
        }

        let pageSize = UInt64(Self.pageSize(from: output) ?? 16_384)
        let pageCounts = Self.pageCounts(from: output)
        let availablePages = [
            "Pages free",
            "Pages inactive",
            "Pages speculative"
        ].reduce(UInt64(0)) { partialResult, key in
            partialResult + UInt64(max(pageCounts[key] ?? 0, 0))
        }

        let availableBytes = availablePages.saturatingMultiply(by: pageSize)
        return min(availableBytes, totalBytes)
    }

    nonisolated private static func pageSize(from output: String) -> Int? {
        guard let firstLine = output.split(separator: "\n").first else { return nil }
        let digits = firstLine.split(separator: " ").compactMap { token -> Int? in
            let cleaned = token.filter(\.isNumber)
            return cleaned.isEmpty ? nil : Int(cleaned)
        }

        return digits.first
    }

    nonisolated private static func pageCounts(from output: String) -> [String: Int64] {
        var result: [String: Int64] = [:]

        for line in output.split(separator: "\n") {
            let parts = line.split(separator: ":", maxSplits: 1)
            guard parts.count == 2 else { continue }

            let key = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let numberText = parts[1].filter(\.isNumber)
            guard !numberText.isEmpty,
                  let value = Int64(numberText) else {
                continue
            }

            result[key] = value
        }

        return result
    }
}

private extension UInt64 {
    nonisolated func saturatingMultiply(by multiplier: UInt64) -> UInt64 {
        let (result, overflow) = multipliedReportingOverflow(by: multiplier)
        return overflow ? UInt64.max : result
    }
}
