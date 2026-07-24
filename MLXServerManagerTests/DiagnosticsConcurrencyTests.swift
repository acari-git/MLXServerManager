import XCTest
@testable import MLXServerManager

@MainActor
final class DiagnosticsConcurrencyTests: XCTestCase {
    func testStaleDiagnosticsCompletionCannotOverwriteReplacementRun() async throws {
        let store = SettingsStore(appDirectoryName: "MLXServerManagerDiagnosticsConcurrencyTests-\(UUID().uuidString)")
        defer {
            if let directory = try? store.settingsDirectoryURL {
                try? FileManager.default.removeItem(at: directory)
            }
        }
        let responder = ControlledDiagnosticsResponder()
        let diagnostics = SetupDiagnostics(
            runOperation: { settings, selectedModel, _ in
                let port = selectedModel?.serverPort ?? settings.defaultPort
                return await responder.run(port: port)
            }
        )
        let viewModel = AppViewModel(
            settingsStore: store,
            setupDiagnostics: diagnostics
        )
        var first = ModelConfig.defaults[0]
        first.modelID = "diagnostics/first"
        first.displayName = "First"
        first.serverPort = 8_101
        var second = ModelConfig.defaults[0]
        second.modelID = "diagnostics/second"
        second.displayName = "Second"
        second.serverPort = 8_102
        viewModel.models = [first, second]

        let staleResult = DiagnosticsResult(
            check: .portAvailability,
            status: .fail,
            message: "stale first result"
        )
        let replacementResult = DiagnosticsResult(
            check: .portAvailability,
            status: .pass,
            message: "replacement second result"
        )

        viewModel.selectedModelID = first.id
        viewModel.runDiagnosticsRequested()
        await waitUntil {
            await responder.hasPending(port: first.serverPort)
        }

        viewModel.selectedModelID = second.id
        viewModel.runDiagnosticsRequested()
        await waitUntil {
            await responder.hasPending(port: second.serverPort)
        }

        await responder.resume(port: second.serverPort, results: [replacementResult])
        await waitUntil {
            viewModel.diagnosticsResults == [replacementResult]
                && viewModel.diagnosticsDidRun
                && !viewModel.isDiagnosticsRunning
        }

        await responder.resume(port: first.serverPort, results: [staleResult])
        for _ in 0..<20 {
            await Task.yield()
        }

        XCTAssertEqual(viewModel.diagnosticsResults, [replacementResult])
        XCTAssertTrue(viewModel.diagnosticsDidRun)
        XCTAssertFalse(viewModel.isDiagnosticsRunning)
        XCTAssertTrue(viewModel.logText.contains("replacement second result"))
        XCTAssertFalse(viewModel.logText.contains("stale first result"))
    }

    func testSelectionChangeCancelsDiagnosticsAndRejectsOriginalResult() async throws {
        let store = SettingsStore(appDirectoryName: "MLXServerManagerDiagnosticsSelectionTests-\(UUID().uuidString)")
        defer {
            if let directory = try? store.settingsDirectoryURL {
                try? FileManager.default.removeItem(at: directory)
            }
        }
        let responder = ControlledDiagnosticsResponder()
        let diagnostics = SetupDiagnostics(
            runOperation: { settings, selectedModel, _ in
                let port = selectedModel?.serverPort ?? settings.defaultPort
                return await responder.run(port: port)
            }
        )
        let viewModel = AppViewModel(
            settingsStore: store,
            setupDiagnostics: diagnostics
        )
        var first = ModelConfig.defaults[0]
        first.modelID = "diagnostics/selection-first"
        first.displayName = "Selection First"
        first.serverPort = 8_201
        var second = ModelConfig.defaults[0]
        second.modelID = "diagnostics/selection-second"
        second.displayName = "Selection Second"
        second.serverPort = 8_202
        viewModel.models = [first, second]

        viewModel.selectedModelID = first.id
        viewModel.runDiagnosticsRequested()
        await waitUntil {
            await responder.hasPending(port: first.serverPort)
        }

        viewModel.selectedModelID = second.id

        XCTAssertFalse(viewModel.isDiagnosticsRunning)
        XCTAssertFalse(viewModel.diagnosticsDidRun)
        XCTAssertTrue(viewModel.diagnosticsResults.isEmpty)
        XCTAssertTrue(viewModel.logText.contains("cancelled because the selected model changed"))

        let originalResult = DiagnosticsResult(
            check: .portAvailability,
            status: .pass,
            message: "result for the original selection"
        )
        await responder.resume(port: first.serverPort, results: [originalResult])
        for _ in 0..<20 {
            await Task.yield()
        }

        XCTAssertFalse(viewModel.isDiagnosticsRunning)
        XCTAssertFalse(viewModel.diagnosticsDidRun)
        XCTAssertTrue(viewModel.diagnosticsResults.isEmpty)
        XCTAssertFalse(viewModel.logText.contains(originalResult.message))
    }

    func testEditingSelectedEndpointCancelsDiagnosticsWithoutWaitingForOldTarget() async throws {
        let store = SettingsStore(appDirectoryName: "MLXServerManagerDiagnosticsEndpointEditTests-\(UUID().uuidString)")
        defer {
            if let directory = try? store.settingsDirectoryURL {
                try? FileManager.default.removeItem(at: directory)
            }
        }
        let responder = ControlledDiagnosticsResponder()
        let diagnostics = SetupDiagnostics(
            runOperation: { settings, selectedModel, _ in
                let port = selectedModel?.serverPort ?? settings.defaultPort
                return await responder.run(port: port)
            }
        )
        let viewModel = AppViewModel(
            settingsStore: store,
            setupDiagnostics: diagnostics
        )
        var model = ModelConfig.defaults[0]
        model.modelID = "diagnostics/endpoint-edit"
        model.displayName = "Endpoint Edit"
        model.serverPort = 8_301
        viewModel.models = [model]
        viewModel.selectedModelID = model.id

        viewModel.runDiagnosticsRequested()
        await waitUntil {
            await responder.hasPending(port: model.serverPort)
        }

        viewModel.editProfileRequested(for: model)
        viewModel.profileEditorDraft.serverPortText = "8302"
        XCTAssertTrue(viewModel.saveProfileEditing())
        XCTAssertFalse(viewModel.isDiagnosticsRunning)
        XCTAssertFalse(viewModel.diagnosticsDidRun)
        XCTAssertTrue(viewModel.diagnosticsResults.isEmpty)
        XCTAssertTrue(viewModel.logText.contains("connection target changed"))

        let staleResult = DiagnosticsResult(
            check: .portAvailability,
            status: .pass,
            message: "result for the old endpoint"
        )
        await responder.resume(port: model.serverPort, results: [staleResult])
        for _ in 0..<20 {
            await Task.yield()
        }

        XCTAssertFalse(viewModel.isDiagnosticsRunning)
        XCTAssertFalse(viewModel.diagnosticsDidRun)
        XCTAssertTrue(viewModel.diagnosticsResults.isEmpty)
        XCTAssertFalse(viewModel.logText.contains(staleResult.message))
    }

    private func waitUntil(
        _ condition: @escaping @MainActor () async -> Bool
    ) async {
        for _ in 0..<300 {
            if await condition() {
                return
            }
            try? await Task.sleep(for: .milliseconds(1))
        }
        XCTFail("Condition was not met before timeout.")
    }
}

private actor ControlledDiagnosticsResponder {
    private var pending: [Int: CheckedContinuation<[DiagnosticsResult], Never>] = [:]

    func run(port: Int) async -> [DiagnosticsResult] {
        await withCheckedContinuation { continuation in
            pending[port] = continuation
        }
    }

    func hasPending(port: Int) -> Bool {
        pending[port] != nil
    }

    func resume(port: Int, results: [DiagnosticsResult]) {
        pending.removeValue(forKey: port)?.resume(returning: results)
    }
}
