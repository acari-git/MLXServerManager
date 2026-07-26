import Foundation
import XCTest
@testable import MLXServerManager

final class V41V50FeatureTests: XCTestCase {
    func testPlatformCompatibilityDeclaresMacOSFifteenAndAppleSilicon() {
        let report = PlatformCompatibilityService().assess()

        XCTAssertEqual(report.minimumSupportedVersion, "15.0")
        XCTAssertEqual(report.architecture, "arm64")
        XCTAssertTrue(report.isAppleSilicon)
        XCTAssertEqual(report.status, .ready)
    }

    func testEvidenceFreshnessDistinguishesCurrentStaleAndUnavailable() {
        let capturedAt = Date(timeIntervalSince1970: 100)
        let currentAt = Date(timeIntervalSince1970: 200)
        let captured = [
            EvidenceFingerprint(domain: .runtime, value: "runtime-a", capturedAt: capturedAt),
            EvidenceFingerprint(domain: .profile, value: "profile-a", capturedAt: capturedAt)
        ]
        let current = [
            EvidenceFingerprint(domain: .runtime, value: "runtime-a", capturedAt: currentAt),
            EvidenceFingerprint(domain: .profile, value: "profile-b", capturedAt: currentAt),
            EvidenceFingerprint(domain: .model, value: "model-a", capturedAt: currentAt)
        ]

        let items = EvidenceFreshnessService().compare(captured: captured, current: current)

        XCTAssertEqual(items.first(where: { $0.domain == .runtime })?.status, .current)
        XCTAssertEqual(items.first(where: { $0.domain == .profile })?.status, .stale)
        XCTAssertEqual(items.first(where: { $0.domain == .model })?.status, .unavailable)
    }

    func testRuntimeDoctorReportsMissingAndReadyExecutables() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("RuntimeDoctor-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let executable = root.appendingPathComponent("mlx_lm.server")
        let script = """
        #!/bin/sh
        if [ "$1" = "--version" ]; then
          echo "mlx-lm test 1.0"
        else
          echo "--model --host --port --chat-template-args"
        fi
        """
        try Data(script.utf8).write(to: executable)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: executable.path
        )

        var settings = AppSettings.defaults
        settings.mlxServerExecutablePath = executable.path
        settings.rapidMLXExecutablePath = root.appendingPathComponent("missing-rapid-mlx").path
        let reports = await RuntimeEnvironmentDoctorService(timeout: 2).assess(settings: settings)

        let mlx = try XCTUnwrap(reports.first(where: { $0.backend == .mlxLM }))
        let rapid = try XCTUnwrap(reports.first(where: { $0.backend == .rapidMLX }))
        XCTAssertEqual(mlx.status, .ready)
        XCTAssertTrue(mlx.issues.contains(where: { $0.kind == .ready }))
        XCTAssertEqual(mlx.version, "mlx-lm test 1.0")
        XCTAssertEqual(rapid.status, .blocking)
        XCTAssertTrue(rapid.issues.contains(where: { $0.kind == .pathMissing }))
    }

    func testRuntimeDoctorDetectsDependencyFailure() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("RuntimeDoctorDependency-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let executable = root.appendingPathComponent("mlx_lm.server")
        let script = """
        #!/bin/sh
        echo "ModuleNotFoundError: No module named mlx_lm" 1>&2
        exit 1
        """
        try Data(script.utf8).write(to: executable)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: executable.path
        )

        var settings = AppSettings.defaults
        settings.mlxServerExecutablePath = executable.path
        let reports = await RuntimeEnvironmentDoctorService(timeout: 2)
            .assess(settings: settings)
        let report = try XCTUnwrap(
            reports.first(where: { $0.backend == .mlxLM })
        )

        XCTAssertEqual(report.status, .blocking)
        XCTAssertTrue(report.issues.contains(where: { $0.kind == .dependencyFailure }))
    }

    func testModelMetadataInspectorReadsCompleteRegisteredModel() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ModelMetadata-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        try Data(#"{"model_type":"qwen3","architectures":["Qwen3ForCausalLM"],"max_position_embeddings":32768,"vocab_size":151936,"quantization_config":{"quant_method":"mlx"}}"#.utf8)
            .write(to: root.appendingPathComponent("config.json"))
        try Data(#"{"chat_template":"{% if tools %}tool{% endif %}"}"#.utf8)
            .write(to: root.appendingPathComponent("tokenizer_config.json"))
        try Data("{}".utf8)
            .write(to: root.appendingPathComponent("tokenizer.json"))
        try Data([1, 2, 3, 4])
            .write(to: root.appendingPathComponent("model.safetensors"))

        let report = await ModelMetadataInspectionService().inspect(
            model: makeModel(id: root.path, localName: root.path)
        )

        XCTAssertEqual(report.status, .compatibleCandidate)
        XCTAssertEqual(report.modelType, "qwen3")
        XCTAssertEqual(report.architectures, ["Qwen3ForCausalLM"])
        XCTAssertEqual(report.contextLength, 32_768)
        XCTAssertEqual(report.vocabularySize, 151_936)
        XCTAssertEqual(report.quantization, "mlx")
        XCTAssertTrue(report.hasTokenizer)
        XCTAssertTrue(report.hasChatTemplate)
        XCTAssertTrue(report.reasoningCandidate)
        XCTAssertTrue(report.toolCallingCandidate)
        XCTAssertEqual(report.weightFileCount, 1)
    }

    func testModelMetadataInspectorKeepsExternalIdentifierOutsideFileSystem() async {
        let report = await ModelMetadataInspectionService().inspect(
            model: makeModel(id: "owner/model", localName: "model")
        )

        XCTAssertEqual(report.status, .externalIdentifier)
        XCTAssertNil(report.localPath)
        XCTAssertEqual(report.weightFileCount, 0)
    }

    func testCapacityPlanningSortsSmallModelsFirstAndDetectsCriticalPlan() {
        let models = [
            makeModel(id: "large", localName: "large", port: 8101),
            makeModel(id: "small", localName: "small", port: 8102)
        ]
        let plan = LaunchPlanDefinition(
            name: "Test",
            steps: [
                LaunchPlanStep(profileID: "large", isRequired: true),
                LaunchPlanStep(profileID: "small", isRequired: true)
            ]
        )
        let assessment = CapacityPlanningService().assess(
            plan: plan,
            models: models,
            estimatedGigabytesByProfileID: ["large": 40, "small": 10],
            runningProfileIDs: [],
            managedMemoryGigabytes: 0,
            systemMemory: SystemMemorySnapshot(
                totalBytes: 64 * 1_073_741_824,
                availableBytes: 45 * 1_073_741_824
            )
        )

        XCTAssertEqual(assessment.level, .critical)
        XCTAssertEqual(assessment.recommendedOrder, ["small", "large"])
        XCTAssertEqual(assessment.candidateGigabytes, 50)
    }

    func testCapacityPlanningPreservesAlreadyRunningProfile() {
        let model = makeModel(id: "running", localName: "running")
        let plan = LaunchPlanDefinition(
            name: "Running",
            steps: [LaunchPlanStep(profileID: model.id, isRequired: true)]
        )
        let assessment = CapacityPlanningService().assess(
            plan: plan,
            models: [model],
            estimatedGigabytesByProfileID: [model.id: 30],
            runningProfileIDs: [model.id],
            managedMemoryGigabytes: 22,
            systemMemory: SystemMemorySnapshot(
                totalBytes: 64 * 1_073_741_824,
                availableBytes: 30 * 1_073_741_824
            )
        )

        XCTAssertEqual(assessment.level, .safe)
        XCTAssertTrue(assessment.items[0].isAlreadyRunning)
        XCTAssertEqual(assessment.candidateGigabytes, 0)
    }

    func testSupportBundleRedactsSecretsAndCompactsHomePaths() {
        let diagnosis = LaunchFailureDiagnosis(
            modelID: "owner/model",
            backend: .mlxLM,
            category: .dependency,
            evidenceLines: ["Authorization: Bearer secret-token"],
            createdAt: Date()
        )
        let runtime = RuntimeDoctorReport(
            backend: .mlxLM,
            executablePath: NSHomeDirectory() + "/.venv/bin/mlx_lm.server",
            version: "1.0",
            interpreterPath: "/usr/bin/python3",
            issues: [RuntimeDoctorIssue(
                id: "test",
                backend: .mlxLM,
                kind: .ready,
                severity: .info,
                title: "token=hf_abcdefghijklmnopqrstuvwxyz",
                detail: "ready",
                commandPreview: nil
            )],
            checkedAt: Date()
        )
        let report = SupportBundleService().makeReport(
            appVersion: "50.0.0",
            platform: PlatformCompatibilityService().assess(),
            runtimeReports: [runtime],
            modelMetadata: nil,
            evidence: [],
            stability: nil,
            capacity: nil,
            launchDiagnosis: diagnosis,
            operationalHistory: [RuntimeEvent(
                category: "Test",
                message: "api_key=private-value"
            )]
        )

        XCTAssertFalse(report.text.contains("secret-token"))
        XCTAssertFalse(report.text.contains("hf_abcdefghijklmnopqrstuvwxyz"))
        XCTAssertFalse(report.text.contains("private-value"))
        XCTAssertFalse(report.text.contains(NSHomeDirectory()))
        XCTAssertTrue(report.text.contains("[REDACTED]"))
    }

    func testLaunchPlanAndCalibrationRoundTripThroughAppSettings() throws {
        let plan = LaunchPlanDefinition(
            name: "Coding",
            steps: [LaunchPlanStep(profileID: "owner/model", isRequired: true)]
        )
        let record = ResourceCalibrationRecord(
            profileID: "owner/model",
            modelID: "owner/model",
            backend: .mlxLM,
            executionFingerprint: "fingerprint",
            totalMemoryGigabytes: 64,
            availableMemoryGigabytes: 32,
            predictedManagedMemoryGigabytes: 20,
            observedManagedMemoryGigabytes: 18,
            benchmarkTTFTMS: 120,
            benchmarkTokensPerSecond: 20,
            benchmarkStabilityPercent: 95
        )
        var settings = AppSettings.defaults
        settings.launchPlans = [plan]
        settings.resourceCalibrationRecords = [record]

        let decoded = try JSONDecoder().decode(
            AppSettings.self,
            from: JSONEncoder().encode(settings)
        )

        XCTAssertEqual(decoded.launchPlans, [plan])
        XCTAssertEqual(decoded.resourceCalibrationRecords, [record])
    }

    private func makeModel(
        id: String,
        localName: String,
        port: Int = 8080
    ) -> ModelConfig {
        ModelConfig(
            modelID: id,
            displayName: URL(fileURLWithPath: id).lastPathComponent,
            family: "Test",
            quantization: "4bit",
            localName: localName,
            host: "127.0.0.1",
            serverPort: port,
            enableThinking: false,
            notes: "",
            advancedLaunchOptions: nil
        )
    }
}

@MainActor
final class OperationsCenterAppViewModelTests: XCTestCase {
    func testCreatingLaunchPlanPersistsDefinitionWithoutStartingServer() throws {
        let store = SettingsStore(
            appDirectoryName: "OperationsCenterViewModel-\(UUID().uuidString)"
        )
        defer {
            if let directory = try? store.settingsDirectoryURL {
                try? FileManager.default.removeItem(at: directory)
            }
        }
        let viewModel = AppViewModel(settingsStore: store)
        XCTAssertTrue(viewModel.runningModelIDs.isEmpty)

        viewModel.createLaunchPlanFromSelectedRequested()

        XCTAssertEqual(viewModel.settings.launchPlans.count, 1)
        XCTAssertEqual(viewModel.settings.launchPlans[0].steps.count, 1)
        XCTAssertTrue(viewModel.runningModelIDs.isEmpty)
        XCTAssertEqual(
            try store.load().settings.launchPlans,
            viewModel.settings.launchPlans
        )
    }

    func testCustomLaunchPlanSavePersistsNameOrderAndRequiredState() throws {
        let store = SettingsStore(
            appDirectoryName: "OperationsCenterCustomPlan-\(UUID().uuidString)"
        )
        defer {
            if let directory = try? store.settingsDirectoryURL {
                try? FileManager.default.removeItem(at: directory)
            }
        }
        let viewModel = AppViewModel(settingsStore: store)
        let first = viewModel.models[0]
        let second = ModelConfig(
            modelID: "owner/custom-second",
            displayName: "Custom Second",
            family: "Test",
            quantization: "4bit",
            localName: "custom-second",
            host: "127.0.0.1",
            serverPort: first.serverPort + 1,
            enableThinking: false,
            notes: "",
            advancedLaunchOptions: nil
        )
        viewModel.models.append(second)
        let plan = LaunchPlanDefinition(
            name: "  Coding Plan  ",
            steps: [
                LaunchPlanStep(profileID: second.id, isRequired: false),
                LaunchPlanStep(profileID: first.id, isRequired: true)
            ]
        )

        viewModel.saveLaunchPlanRequested(plan)

        let persisted = try XCTUnwrap(store.load().settings.launchPlans.first)
        XCTAssertEqual(persisted.name, "Coding Plan")
        XCTAssertEqual(persisted.steps.map(\.profileID), [second.id, first.id])
        XCTAssertFalse(persisted.steps[0].isRequired)
        XCTAssertTrue(persisted.steps[1].isRequired)
        XCTAssertTrue(viewModel.runningModelIDs.isEmpty)
    }

    func testDeletingLaunchPlanDoesNotChangeRunningOwnership() {
        let store = SettingsStore(
            appDirectoryName: "OperationsCenterDeletePlan-\(UUID().uuidString)"
        )
        defer {
            if let directory = try? store.settingsDirectoryURL {
                try? FileManager.default.removeItem(at: directory)
            }
        }
        let viewModel = AppViewModel(settingsStore: store)
        viewModel.createLaunchPlanFromSelectedRequested()
        let plan = viewModel.settings.launchPlans[0]

        viewModel.deleteLaunchPlanRequested(plan)

        XCTAssertTrue(viewModel.settings.launchPlans.isEmpty)
        XCTAssertTrue(viewModel.runningModelIDs.isEmpty)
    }

    func testLaunchPlanRequiredStateAndOrderPersistWithoutStartingServers() throws {
        let store = SettingsStore(
            appDirectoryName: "OperationsCenterPlanEdit-\(UUID().uuidString)"
        )
        defer {
            if let directory = try? store.settingsDirectoryURL {
                try? FileManager.default.removeItem(at: directory)
            }
        }
        let viewModel = AppViewModel(settingsStore: store)
        let first = ModelConfig(
            modelID: "owner/first",
            displayName: "First",
            family: "Test",
            quantization: "4bit",
            localName: "first",
            host: "127.0.0.1",
            serverPort: 8_201,
            enableThinking: false,
            notes: "",
            advancedLaunchOptions: nil
        )
        let second = ModelConfig(
            modelID: "owner/second",
            displayName: "Second",
            family: "Test",
            quantization: "4bit",
            localName: "second",
            host: "127.0.0.1",
            serverPort: 8_202,
            enableThinking: false,
            notes: "",
            advancedLaunchOptions: nil
        )
        viewModel.models = [first, second]
        let plan = LaunchPlanDefinition(
            name: "Ordered",
            steps: [
                LaunchPlanStep(profileID: first.id, isRequired: true),
                LaunchPlanStep(profileID: second.id, isRequired: true)
            ]
        )
        var nextSettings = viewModel.settings
        nextSettings.launchPlans = [plan]
        XCTAssertTrue(viewModel.saveSettingsRequested(nextSettings))

        viewModel.setLaunchPlanStepRequiredRequested(
            plan,
            profileID: second.id,
            isRequired: false
        )
        let updatedPlan = viewModel.settings.launchPlans[0]
        viewModel.moveLaunchPlanStepRequested(
            updatedPlan,
            profileID: second.id,
            offset: -1
        )

        let persisted = try store.load().settings.launchPlans[0]
        XCTAssertEqual(persisted.steps.map(\.profileID), [second.id, first.id])
        XCTAssertFalse(persisted.steps[0].isRequired)
        XCTAssertTrue(persisted.steps[1].isRequired)
        XCTAssertTrue(viewModel.runningModelIDs.isEmpty)
    }

    func testStabilityCheckRequiresAppOwnedRunningServer() {
        let store = SettingsStore(
            appDirectoryName: "OperationsCenterStability-\(UUID().uuidString)"
        )
        defer {
            if let directory = try? store.settingsDirectoryURL {
                try? FileManager.default.removeItem(at: directory)
            }
        }
        let viewModel = AppViewModel(settingsStore: store)

        viewModel.runLaunchStabilityCheckRequested()

        XCTAssertEqual(viewModel.operationsCenterViewState.stability?.status, .notRunning)
    }

    func testSupportBundleIsGeneratedInMemoryOnly() {
        let store = SettingsStore(
            appDirectoryName: "OperationsCenterSupport-\(UUID().uuidString)"
        )
        defer {
            if let directory = try? store.settingsDirectoryURL {
                try? FileManager.default.removeItem(at: directory)
            }
        }
        let viewModel = AppViewModel(settingsStore: store)

        viewModel.generateSupportBundleRequested()

        XCTAssertNotNil(viewModel.operationsCenterViewState.supportBundle)
        XCTAssertTrue(
            viewModel.operationsCenterViewState.supportBundle?.text.contains("Direct Mode: enabled") == true
        )
    }
}
