import Foundation
import XCTest
@testable import MLXServerManager

final class AppViewModelAsyncOwnershipTests: XCTestCase {
    func testAppViewModelFilesDoNotOwnRawTasks() throws {
        let root = try Self.projectRoot()
        let directory = root.appendingPathComponent("MLXServerManager/ViewModels")
        let files = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )
        .filter {
            $0.lastPathComponent == "AppViewModel.swift"
                || $0.lastPathComponent.hasPrefix("AppViewModel+")
        }
        .filter { $0.pathExtension == "swift" }

        let forbiddenPatterns = [
            #"\bTask\s*\{"#,
            #"\bTask\.detached\s*\{"#,
            #"\bTask\s*<"#
        ]
        let expressions = try forbiddenPatterns.map { pattern in
            try NSRegularExpression(pattern: pattern)
        }
        var findings: [String] = []

        for file in files {
            let text = try String(contentsOf: file, encoding: .utf8)
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            for expression in expressions {
                for match in expression.matches(in: text, range: range) {
                    guard let matchRange = Range(match.range, in: text) else { continue }
                    let line = text[..<matchRange.lowerBound].reduce(into: 1) { count, character in
                        if character == "\n" {
                            count += 1
                        }
                    }
                    findings.append("\(file.lastPathComponent):\(line): \(text[matchRange])")
                }
            }
        }

        XCTAssertTrue(
            findings.isEmpty,
            "AppViewModel files must delegate asynchronous ownership to coordinators.\n"
                + findings.joined(separator: "\n")
        )
    }

    func testAppViewModelDeclaresRequiredAsyncCoordinators() throws {
        let root = try Self.projectRoot()
        let sourceURL = root.appendingPathComponent("MLXServerManager/ViewModels/AppViewModel.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)
        let requiredProperties = [
            "diagnosticsRunCoordinator",
            "miniChatRunCoordinator",
            "profileDeletionUndoRunCoordinator",
            "profileDeletionCacheRunCoordinator",
            "readyCheckRunCoordinator",
            "systemHardwareInfoRunCoordinator",
            "modelStartPreparationCoordinator",
            "managedStartRunCoordinator",
            "lifecycleRunCoordinator",
            "benchmarkRunCoordinator",
            "agenticBenchmarkRunCoordinator",
            "huggingFaceOutputStateCoordinator",
            "managedModelOutputCoordinator",
            "modelSizeEstimationCoordinator",
            "runtimeReadinessRunCoordinator",
            "runtimeSetupAssistantRunCoordinator",
            "runtimeCompatibilityRunCoordinator",
            "applicationTerminationCoordinator",
            "sessionRecoveryCoordinator"
        ]
        let missing = requiredProperties.filter { !source.contains($0) }

        XCTAssertTrue(
            missing.isEmpty,
            "AppViewModel must keep async ownership behind the expected coordinators: \(missing)"
        )
    }

    private static func projectRoot() throws -> URL {
        var directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        while directory.path != "/" {
            if FileManager.default.fileExists(
                atPath: directory.appendingPathComponent("MLXServerManager.xcodeproj").path
            ) {
                return directory
            }
            directory.deleteLastPathComponent()
        }
        throw NSError(domain: "AppViewModelAsyncOwnershipTests", code: 1)
    }
}
