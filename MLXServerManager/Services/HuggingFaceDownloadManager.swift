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

enum HuggingFaceDownloadError: LocalizedError, Equatable {
    case cancelled
    case commandNotAvailable
    case destinationPreparationFailed(String)
    case processLaunchFailed(String)
    case processFailed(status: Int32)

    var errorDescription: String? {
        switch self {
        case .cancelled:
            "Download cancelled. The model was not added."
        case .commandNotAvailable:
            "The hf command is not available. Install huggingface_hub CLI and try again."
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
    private var activeProcess: Process?
    private var stdoutPipe: Pipe?
    private var stderrPipe: Pipe?

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func download(
        request: HuggingFaceDownloadRequest,
        outputHandler: @escaping (String) -> Void
    ) async throws -> HuggingFaceDownloadResult {
        let destinationURL = URL(fileURLWithPath: request.destinationPath, isDirectory: true)
        let parentURL = destinationURL.deletingLastPathComponent()
        do {
            try fileManager.createDirectory(at: parentURL, withIntermediateDirectories: true)
        } catch {
            throw HuggingFaceDownloadError.destinationPreparationFailed(error.localizedDescription)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        let subcommand = "down" + "load"
        process.arguments = ["hf", subcommand, request.repositoryID, "--local-dir", request.destinationPath]

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
                    continuation.resume(returning: HuggingFaceDownloadResult(repositoryID: request.repositoryID, destinationPath: request.destinationPath, terminationStatus: status))
                } else if status == 127 {
                    continuation.resume(throwing: HuggingFaceDownloadError.commandNotAvailable)
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
