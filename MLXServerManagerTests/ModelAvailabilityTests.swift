import XCTest
@testable import MLXServerManager

final class ModelAvailabilityTests: XCTestCase {
    func testIdentifierOnlyProfileMapsToConfiguredAndCannotCheck() {
        let model = makeModel(modelID: "unsloth/example-mlx-4bit", localName: "example-mlx-4bit")

        let summary = ModelAvailabilitySummary.initial(for: model, isExternalTarget: false)

        XCTAssertEqual(summary.state, .configured)
        XCTAssertEqual(summary.configuredTarget, "unsloth/example-mlx-4bit")
        XCTAssertEqual(summary.checkedPathSummary, "No local path configured")
        XCTAssertFalse(summary.canCheck)
    }

    func testHomePathProfileMapsToUnknownAndCanCheck() {
        let model = makeModel(modelID: "~/Models/mlx/example", localName: "example")

        let summary = ModelAvailabilitySummary.initial(for: model, isExternalTarget: false)

        XCTAssertEqual(summary.state, .unknown)
        XCTAssertEqual(summary.checkedPathSummary, "~/Models/mlx/example")
        XCTAssertTrue(summary.canCheck)
    }

    func testExternalTargetMapsToExternalAndCannotCheck() {
        let model = makeModel(modelID: "external/model", localName: "model")

        let summary = ModelAvailabilitySummary.initial(for: model, isExternalTarget: true)

        XCTAssertEqual(summary.state, .external)
        XCTAssertFalse(summary.canCheck)
        XCTAssertEqual(summary.scopeText, "External targets are not managed by MLX Server Manager.")
    }

    func testPresentResultUsesCopySafeHomePath() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let path = home + "/Models/mlx/example"
        let model = makeModel(modelID: path, localName: "example")

        let summary = ModelAvailabilitySummary.checked(for: model, result: .present(path: path))

        XCTAssertEqual(summary.state, .present)
        XCTAssertEqual(summary.checkedPathSummary, "~/Models/mlx/example")
        XCTAssertTrue(summary.canCheck)
        XCTAssertTrue(summary.nextStep.contains("does not confirm"))
    }

    func testMissingResultUsesMissingState() {
        let path = "/tmp/mlxservermanager-missing-model"
        let model = makeModel(modelID: path, localName: "missing-model")

        let summary = ModelAvailabilitySummary.checked(for: model, result: .missing(path: path))

        XCTAssertEqual(summary.state, .missing)
        XCTAssertEqual(summary.checkedPathSummary, path)
        XCTAssertTrue(summary.canCheck)
    }

    func testFileSystemCheckerReportsPresentAndMissingPaths() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }

        let checker = FileSystemLocalModelAvailabilityChecker()

        XCTAssertEqual(checker.check(path: temporaryDirectory.path), .present(path: temporaryDirectory.path))
        XCTAssertEqual(
            checker.check(path: temporaryDirectory.appendingPathComponent("missing").path),
            .missing(path: temporaryDirectory.appendingPathComponent("missing").path)
        )
    }

    func testPathFormatterExpandsHomeAndFileURL() {
        let homePath = FileManager.default.homeDirectoryForCurrentUser.path
        XCTAssertEqual(
            ModelAvailabilityPathFormatter.expandedLocalPath(from: "~/Models/mlx/example"),
            homePath + "/Models/mlx/example"
        )

        XCTAssertEqual(
            ModelAvailabilityPathFormatter.expandedLocalPath(from: "file:///tmp/example"),
            "/tmp/example"
        )

        XCTAssertNil(ModelAvailabilityPathFormatter.expandedLocalPath(from: "unsloth/example"))
    }

    private func makeModel(modelID: String, localName: String) -> ModelConfig {
        ModelConfig(
            modelID: modelID,
            displayName: "Example",
            family: "Example",
            quantization: "Test",
            localName: localName,
            host: "127.0.0.1",
            serverPort: 8080,
            enableThinking: false,
            notes: "",
            advancedLaunchOptions: nil
        )
    }
}
