import Darwin
import Foundation

nonisolated struct ShortLivedProcessResult: Equatable, Sendable {
    let standardOutput: Data
    let standardError: Data
    let terminationStatus: Int32
    let timedOut: Bool
    let cancelled: Bool
}

nonisolated enum ShortLivedProcessRunner {
    private enum WaitResult: Equatable {
        case exited
        case timedOut
        case cancelled
    }

    static func runAsync(
        executablePath: String,
        arguments: [String],
        environment: [String: String]? = nil,
        timeout: TimeInterval,
        terminationGracePeriod: TimeInterval = 0.2,
        maximumCapturedOutputBytes: Int = 1_048_576
    ) async -> ShortLivedProcessResult? {
        let cancellationState = ProcessCancellationState()
        if Task.isCancelled {
            cancellationState.cancel()
        }

        return await withTaskCancellationHandler {
            await Task.detached(priority: .utility) {
                run(
                    executablePath: executablePath,
                    arguments: arguments,
                    environment: environment,
                    timeout: timeout,
                    terminationGracePeriod: terminationGracePeriod,
                    maximumCapturedOutputBytes: maximumCapturedOutputBytes,
                    cancellationCheck: { cancellationState.isCancelled }
                )
            }.value
        } onCancel: {
            cancellationState.cancel()
        }
    }

    static func run(
        executablePath: String,
        arguments: [String],
        environment: [String: String]? = nil,
        timeout: TimeInterval,
        terminationGracePeriod: TimeInterval = 0.2,
        maximumCapturedOutputBytes: Int = 1_048_576,
        fileManager: FileManager = .default,
        cancellationCheck: @escaping @Sendable () -> Bool = { false }
    ) -> ShortLivedProcessResult? {
        guard !cancellationCheck() else { return nil }

        let workingDirectory = fileManager.temporaryDirectory
            .appendingPathComponent("MLXServerManager-Command-\(UUID().uuidString)", isDirectory: true)
        let stdoutURL = workingDirectory.appendingPathComponent("stdout")
        let stderrURL = workingDirectory.appendingPathComponent("stderr")

        do {
            try fileManager.createDirectory(at: workingDirectory, withIntermediateDirectories: true)
        } catch {
            return nil
        }
        defer { try? fileManager.removeItem(at: workingDirectory) }

        guard fileManager.createFile(atPath: stdoutURL.path, contents: nil),
              fileManager.createFile(atPath: stderrURL.path, contents: nil),
              let stdoutHandle = try? FileHandle(forWritingTo: stdoutURL),
              let stderrHandle = try? FileHandle(forWritingTo: stderrURL) else {
            return nil
        }

        var outputHandlesAreOpen = true
        defer {
            if outputHandlesAreOpen {
                try? stdoutHandle.close()
                try? stderrHandle.close()
            }
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments
        process.environment = environment
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = stdoutHandle
        process.standardError = stderrHandle

        do {
            try process.run()
        } catch {
            return nil
        }

        try? stdoutHandle.close()
        try? stderrHandle.close()
        outputHandlesAreOpen = false

        let waitResult = waitForExit(
            process,
            timeout: timeout,
            cancellationCheck: cancellationCheck
        )
        let timedOut = waitResult == .timedOut
        let cancelled = waitResult == .cancelled
        if waitResult != .exited {
            guard terminate(process, gracePeriod: terminationGracePeriod) else {
                return nil
            }
        }

        let capturedByteLimit = max(0, maximumCapturedOutputBytes)
        guard let standardOutput = boundedData(
            at: stdoutURL,
            maximumBytes: capturedByteLimit,
            fileManager: fileManager
        ),
        let standardError = boundedData(
            at: stderrURL,
            maximumBytes: capturedByteLimit,
            fileManager: fileManager
        ) else {
            return nil
        }

        return ShortLivedProcessResult(
            standardOutput: standardOutput,
            standardError: standardError,
            terminationStatus: process.terminationStatus,
            timedOut: timedOut,
            cancelled: cancelled
        )
    }

    private static func terminate(_ process: Process, gracePeriod: TimeInterval) -> Bool {
        let processIdentifier = process.processIdentifier
        process.terminate()
        if waitForExit(process, timeout: gracePeriod) == .exited {
            return true
        }

        process.interrupt()
        if waitForExit(process, timeout: gracePeriod) == .exited {
            return true
        }

        Darwin.kill(processIdentifier, SIGKILL)
        return waitForExit(process, timeout: max(1, gracePeriod)) == .exited
    }

    private static func waitForExit(
        _ process: Process,
        timeout: TimeInterval,
        cancellationCheck: @Sendable () -> Bool = { false }
    ) -> WaitResult {
        let deadline = Date().addingTimeInterval(max(0, timeout))
        while process.isRunning {
            guard !cancellationCheck() else { return .cancelled }
            let remaining = deadline.timeIntervalSinceNow
            guard remaining > 0 else { return .timedOut }
            Thread.sleep(forTimeInterval: min(0.01, remaining))
        }
        return .exited
    }

    private static func boundedData(
        at url: URL,
        maximumBytes: Int,
        fileManager: FileManager
    ) -> Data? {
        guard maximumBytes > 0,
              let attributes = try? fileManager.attributesOfItem(atPath: url.path),
              let size = (attributes[.size] as? NSNumber)?.uint64Value else {
            return maximumBytes == 0 ? Data() : nil
        }

        guard let handle = try? FileHandle(forReadingFrom: url) else {
            return nil
        }
        defer { try? handle.close() }

        let maximumSize = UInt64(maximumBytes)
        guard size > maximumSize else {
            return handle.readDataToEndOfFile()
        }

        let prefixLength = maximumBytes / 2
        let suffixLength = maximumBytes - prefixLength
        let prefix = handle.readData(ofLength: prefixLength)
        do {
            try handle.seek(toOffset: size - UInt64(suffixLength))
        } catch {
            return nil
        }
        let suffix = handle.readData(ofLength: suffixLength)

        var result = prefix
        result.append(Data("\n...[output truncated]...\n".utf8))
        result.append(suffix)
        return result
    }
}

private nonisolated final class ProcessCancellationState: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false

    var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return value
    }

    func cancel() {
        lock.lock()
        value = true
        lock.unlock()
    }
}
