import XCTest
@testable import MLXServerManager

final class ModelStartPreflightEvaluatorTests: XCTestCase {
    private let evaluator = ModelStartPreflightEvaluator()

    func testMissingExecutablePathIsReportedBeforePortState() {
        let issue = evaluator.evaluate(
            model: makeModel(modelID: "owner/model"),
            executablePath: "  ",
            managedEndpointConflict: nil,
            portCheckResult: .busy(host: "127.0.0.1", port: 8080, pid: 42)
        )

        XCTAssertEqual(issue, .missingExecutablePath(backend: .mlxLM))
        XCTAssertEqual(issue?.blockingMessage(language: .english), "Missing executable path")
        XCTAssertEqual(issue?.blockingMessage(language: .japanese), "実行ファイルパスが未設定")
    }

    func testMissingLocalModelPathIsReported() {
        let missingPath = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .path
        let issue = evaluator.evaluateStatic(
            model: makeModel(modelID: missingPath),
            executablePath: "/usr/bin/true",
            managedEndpointConflict: nil
        )

        XCTAssertEqual(issue, .missingModelPath(path: missingPath))
        XCTAssertTrue(issue?.launchMessage(language: .english).contains("Model path is missing") == true)
    }

    func testManagedEndpointConflictIsReportedBeforeExternalPortState() throws {
        let modelDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: modelDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: modelDirectory) }

        let issue = evaluator.evaluate(
            model: makeModel(modelID: modelDirectory.path),
            executablePath: "/usr/bin/true",
            managedEndpointConflict: ManagedModelEndpointConflict(
                modelDisplayName: "Loaded Model",
                processIdentifier: 123
            ),
            portCheckResult: .available(host: "127.0.0.1", port: 8080)
        )

        XCTAssertEqual(
            issue,
            .managedEndpointConflict(
                host: "127.0.0.1",
                port: 8080,
                modelDisplayName: "Loaded Model",
                processIdentifier: 123
            )
        )
        XCTAssertTrue(issue?.isManagedEndpointConflict == true)
    }

    func testValidStaticInputsAndAvailablePortPass() throws {
        let modelDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: modelDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: modelDirectory) }

        let issue = evaluator.evaluate(
            model: makeModel(modelID: modelDirectory.path),
            executablePath: "/usr/bin/true",
            managedEndpointConflict: nil,
            portCheckResult: .available(host: "127.0.0.1", port: 8080)
        )

        XCTAssertNil(issue)
    }

    func testContentValidationBlocksIncompleteLocalModel() throws {
        let modelDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: modelDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: modelDirectory) }

        let issue = evaluator.evaluateLocal(
            model: makeModel(modelID: modelDirectory.path),
            executablePath: "/usr/bin/true",
            validateModelContents: true
        )

        XCTAssertEqual(
            issue,
            .incompleteModelDirectory(path: modelDirectory.path, issue: .missingConfiguration)
        )
        XCTAssertTrue(issue?.launchMessage(language: .japanese).contains("config.json") == true)
    }

    func testContentValidationAllowsCompleteLocalModel() throws {
        let modelDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: modelDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: modelDirectory) }
        try Data(#"{"model_type":"test"}"#.utf8)
            .write(to: modelDirectory.appendingPathComponent("config.json"))
        try Data(#"{"version":"1.0"}"#.utf8)
            .write(to: modelDirectory.appendingPathComponent("tokenizer.json"))
        try Data([1]).write(to: modelDirectory.appendingPathComponent("model.safetensors"))

        let issue = evaluator.evaluateLocal(
            model: makeModel(modelID: modelDirectory.path),
            executablePath: "/usr/bin/true",
            validateModelContents: true
        )

        XCTAssertNil(issue)
    }

    func testBusyPortRetainsLocalizedDiagnostic() {
        let issue = evaluator.evaluate(
            model: makeModel(modelID: "owner/model"),
            executablePath: "/usr/bin/true",
            managedEndpointConflict: nil,
            portCheckResult: .busy(host: "127.0.0.1", port: 8080, pid: 77)
        )

        XCTAssertEqual(
            issue?.blockingMessage(language: .english),
            "Server port: Busy (PID: 77)"
        )
        XCTAssertEqual(
            issue?.blockingMessage(language: .japanese),
            "Server port: 使用中（PID: 77）"
        )
    }

    private func makeModel(modelID: String) -> ModelConfig {
        ModelConfig(
            modelID: modelID,
            displayName: "Test Model",
            family: "Test",
            quantization: "4-bit",
            localName: "Test-Model",
            host: "127.0.0.1",
            serverPort: 8080,
            enableThinking: false,
            notes: "",
            advancedLaunchOptions: nil
        )
    }
}
