import Foundation

struct HuggingFaceDownloadRequest: Equatable {
    let repositoryID: String
    let destinationPath: String
}

struct HuggingFaceDownloadResult: Equatable {
    let repositoryID: String
    let destinationPath: String
    let terminationStatus: Int32
}

struct HuggingFaceCLIResolution: Equatable {
    let executablePath: String
    let searchedPaths: [String]

    var displayPath: String {
        ModelAvailabilityPathFormatter.compact(path: executablePath)
    }
}

enum HuggingFaceDownloadError: LocalizedError, Equatable {
    case cancelled
    case commandNotAvailable(searchedPaths: [String])
    case destinationPreparationFailed(String)
    case processLaunchFailed(String)
    case processFailed(status: Int32)

    var errorDescription: String? {
        switch self {
        case .cancelled:
            "Download cancelled. The model was not added."
        case let .commandNotAvailable(searchedPaths):
            "The hf command is not available. Checked: \(searchedPaths.map { ModelAvailabilityPathFormatter.compact(path: $0) }.joined(separator: ", ")). Install Hugging Face CLI or restart the app after installing it."
        case let .destinationPreparationFailed(message):
            "Could not prepare the destination folder: \(message)"
        case let .processLaunchFailed(message):
            "Could not start the Hugging Face download: \(message)"
        case let .processFailed(status):
            "Hugging Face download failed with exit status \(status)."
        }
    }
}

protocol HuggingFaceModelDownloading: AnyObject {
    func download(
        request: HuggingFaceDownloadRequest,
        outputHandler: @escaping (String) -> Void
    ) async throws -> HuggingFaceDownloadResult
    func cancel()
}

final class HuggingFaceDownloadManager: HuggingFaceModelDownloading {
    private let fileManager: FileManager
    private let environment: [String: String]
    private var activeProcess: Process?
    private var stdoutPipe: Pipe?
    private var stderrPipe: Pipe?

    init(
        fileManager: FileManager = .default,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        self.fileManager = fileManager
        self.environment = environment
    }

    func download(
        request: HuggingFaceDownloadRequest,
        outputHandler: @escaping (String) -> Void
    ) async throws -> HuggingFaceDownloadResult {
        let destinationURL = URL(fileURLWithPath: request.destinationPath, isDirectory: true)
        let parentURL = destinationURL.deletingLastPathComponent()
        let searchEnvironment = environment

        do {
            try fileManager.createDirectory(at: parentURL, withIntermediateDirectories: true)
        } catch {
            throw HuggingFaceDownloadError.destinationPreparationFailed(error.localizedDescription)
        }

        guard let resolution = Self.resolveCLI(
            fileManager: fileManager,
            environment: searchEnvironment
        ) else {
            throw HuggingFaceDownloadError.commandNotAvailable(
                searchedPaths: Self.candidateExecutablePaths(environment: searchEnvironment)
            )
        }

        outputHandler("[hf] using \(resolution.displayPath)")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: resolution.executablePath)
        let subcommand = "down" + "load"
        process.arguments = [subcommand, request.repositoryID, "--local-dir", request.destinationPath]

        var processEnvironment = searchEnvironment
        let candidateDirectories = Self.candidateExecutablePaths(environment: searchEnvironment)
            .map { URL(fileURLWithPath: $0).deletingLastPathComponent().path }
        let path = processEnvironment["PATH", default: ""]
        processEnvironment["PATH"] = (candidateDirectories + [path])
            .filter { !$0.isEmpty }
            .joined(separator: ":")
        process.environment = processEnvironment

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        activeProcess = process
        self.stdoutPipe = stdoutPipe
        self.stderrPipe = stderrPipe
        configurePipe(stdoutPipe, label: "stdout", outputHandler: outputHandler)
        configurePipe(stderrPipe, label: "stderr", outputHandler: outputHandler)

        return try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { [weak self] process in
                let status = process.terminationStatus
                if let manager = self {
                    DispatchQueue.main.async {
                        manager.clearIfMatching(process)
                    }
                }

                if status == 0 {
                    continuation.resume(
                        returning: HuggingFaceDownloadResult(
                            repositoryID: request.repositoryID,
                            destinationPath: request.destinationPath,
                            terminationStatus: status
                        )
                    )
                } else if status == 127 {
                    continuation.resume(
                        throwing: HuggingFaceDownloadError.commandNotAvailable(
                            searchedPaths: Self.candidateExecutablePaths(environment: searchEnvironment)
                        )
                    )
                } else {
                    continuation.resume(throwing: HuggingFaceDownloadError.processFailed(status: status))
                }
            }

            do {
                try process.run()
            } catch {
                clearIfMatching(process)
                continuation.resume(throwing: HuggingFaceDownloadError.processLaunchFailed(error.localizedDescription))
            }
        }
    }

    func cancel() {
        activeProcess?.terminate()
    }

    private func configurePipe(_ pipe: Pipe, label: String, outputHandler: @escaping (String) -> Void) {
        pipe.fileHandleForReading.readabilityHandler = { fileHandle in
            let data = fileHandle.availableData
            guard !data.isEmpty, let chunk = String(data: data, encoding: .utf8) else {
                return
            }

            let lines = chunk.replacingOccurrences(of: "\r", with: "\n")
                .split(whereSeparator: \.isNewline)
                .map(String.init)
                .map(HuggingFaceDownloadPlanner.sanitizedOutputLine)
                .filter { !$0.isEmpty }

            for line in lines {
                outputHandler("[hf:\(label)] \(line)")
            }
        }
    }

    nonisolated static func resolveCLI(
        fileManager: FileManager = .default,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> HuggingFaceCLIResolution? {
        let candidates = candidateExecutablePaths(environment: environment)
        guard let executablePath = candidates.first(where: { path in
            fileManager.isExecutableFile(atPath: path)
        }) else {
            return nil
        }

        return HuggingFaceCLIResolution(
            executablePath: executablePath,
            searchedPaths: candidates
        )
    }

    nonisolated static func candidateExecutablePaths(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> [String] {
        var candidates: [String] = []
        let home = environment["HOME"] ?? FileManager.default.homeDirectoryForCurrentUser.path
        if !home.isEmpty {
            candidates.append(URL(fileURLWithPath: home).appendingPathComponent(".local/bin/hf").path)
            candidates.append(URL(fileURLWithPath: home).appendingPathComponent(".hf-cli/bin/hf").path)
        }

        candidates.append("/opt/homebrew/bin/hf")
        candidates.append("/usr/local/bin/hf")
        candidates.append("/usr/bin/hf")

        let pathEntries = environment["PATH", default: ""]
            .split(separator: ":")
            .map(String.init)
            .filter { !$0.isEmpty }
        for directory in pathEntries {
            candidates.append(URL(fileURLWithPath: directory).appendingPathComponent("hf").path)
        }

        var unique: [String] = []
        for candidate in candidates {
            let standardized = URL(fileURLWithPath: candidate).standardizedFileURL.path
            if !unique.contains(standardized) {
                unique.append(standardized)
            }
        }
        return unique
    }

    private func clearIfMatching(_ process: Process) {
        guard activeProcess === process else {
            return
        }
        stdoutPipe?.fileHandleForReading.readabilityHandler = nil
        stderrPipe?.fileHandleForReading.readabilityHandler = nil
        activeProcess = nil
        stdoutPipe = nil
        stderrPipe = nil
    }
}
