import Foundation
import XCTest
@testable import MLXServerManager

final class V35V40FeatureTests: XCTestCase {
    func testProfileCompatibilityBlocksOnlyKnownUnsupportedRequestedFlags() {
        let request = ModelLaunchRequest(
            executablePath: "/tmp/rapid-mlx",
            backend: .rapidMLX,
            modelID: "owner/model",
            host: "127.0.0.1",
            port: 8080,
            enableThinking: false,
            advancedLaunchOptions: AdvancedLaunchOptions(defaultTemperature: "0.7")
        )
        let report = RuntimeCompatibilityReport(
            backend: .rapidMLX,
            executablePath: "/tmp/rapid-mlx",
            version: "1.0",
            supportedFlags: ["--host", "--port", "--no-thinking"],
            features: [],
            checkedAt: Date()
        )

        let assessment = RuntimeProfileCompatibilityAdvisor.assess(
            request: request,
            report: report
        )

        XCTAssertEqual(assessment.level, .blocked)
        XCTAssertEqual(assessment.unsupportedFlags, ["--default-temperature"])
        XCTAssertTrue(assessment.requestedFlags.contains("--no-thinking"))
    }

    func testUnknownCompatibilityDoesNotClaimUnsupported() {
        let request = ModelLaunchRequest(
            executablePath: "/tmp/mlx_lm.server",
            backend: .mlxLM,
            modelID: "owner/model",
            host: "127.0.0.1",
            port: 8080,
            enableThinking: true,
            advancedLaunchOptions: nil
        )

        let assessment = RuntimeProfileCompatibilityAdvisor.assess(
            request: request,
            report: nil
        )

        XCTAssertEqual(assessment.level, .unknown)
        XCTAssertTrue(assessment.unsupportedFlags.isEmpty)
        XCTAssertTrue(assessment.requestedFlags.contains("--chat-template-args"))
    }

    func testCompatibilityReportForDifferentExecutablePathIsTreatedAsUnknown() {
        let request = ModelLaunchRequest(
            executablePath: "~/runtime-b/mlx_lm.server",
            backend: .mlxLM,
            modelID: "owner/model",
            host: "127.0.0.1",
            port: 8080,
            enableThinking: true,
            advancedLaunchOptions: nil
        )
        let report = RuntimeCompatibilityReport(
            backend: .mlxLM,
            executablePath: "~/runtime-a/mlx_lm.server",
            version: "1.0",
            supportedFlags: ["--model", "--host", "--port"],
            features: [],
            checkedAt: Date()
        )

        let assessment = RuntimeProfileCompatibilityAdvisor.assess(
            request: request,
            report: report
        )

        XCTAssertEqual(assessment.level, .unknown)
        XCTAssertTrue(assessment.unsupportedFlags.isEmpty)
    }

    func testClearingUnsupportedOptionsChangesOnlyMatchingDraftFields() {
        var draft = ModelProfileDraft.newProfile(defaultHost: "127.0.0.1", defaultPort: 8080)
        draft.modelID = "owner/model"
        draft.enableThinking = true
        draft.advancedLaunchOptions.defaultTemperature = "0.7"
        draft.advancedLaunchOptions.defaultTopP = "0.9"
        draft.advancedLaunchOptions.allowedOrigins = "http://localhost"

        let cleared = RuntimeProfileCompatibilityAdvisor.clearingUnsupportedOptions(
            in: draft,
            flags: ["--chat-template-args", "--temp"]
        )

        XCTAssertFalse(cleared.enableThinking)
        XCTAssertNil(cleared.advancedLaunchOptions.defaultTemperature)
        XCTAssertEqual(cleared.advancedLaunchOptions.defaultTopP, "0.9")
        XCTAssertEqual(cleared.advancedLaunchOptions.allowedOrigins, "http://localhost")
    }

    func testLaunchFailureClassifierFindsDependencyAndRedactsSecrets() {
        let diagnosis = LaunchFailureClassifier.classify(
            modelID: "owner/model",
            backend: .mlxLM,
            lines: [
                "[stderr] ModuleNotFoundError: No module named 'mlx_lm'",
                "[stderr] Authorization: Bearer secret-value"
            ],
            fallbackMessage: "Launch failed"
        )

        XCTAssertEqual(diagnosis.category, .dependency)
        XCTAssertFalse(diagnosis.copyText(language: .english).contains("secret-value"))
    }

    func testLaunchFailureCoordinatorBoundsEvidenceAndClearsState() async {
        let coordinator = await MainActor.run {
            LaunchFailureDiagnosticCoordinator(maximumLinesPerModel: 10)
        }
        await MainActor.run {
            coordinator.begin(modelID: "owner/model")
            for index in 0..<20 {
                coordinator.append("error line \(index)", modelID: "owner/model")
            }
        }
        let diagnosis = await MainActor.run {
            coordinator.diagnose(
                modelID: "owner/model",
                backend: .mlxLM,
                fallbackMessage: "failed"
            )
        }

        XCTAssertLessThanOrEqual(diagnosis.evidenceLines.count, 5)
        XCTAssertEqual(diagnosis.evidenceLines.last, "error line 19")
    }

    func testRegisteredModelHealthChecksOnlyRegisteredPathsAndDetectsSharedPath() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try Data(#"{"model_type":"test"}"#.utf8)
            .write(to: root.appendingPathComponent("config.json"))
        try Data("{}".utf8)
            .write(to: root.appendingPathComponent("tokenizer.json"))
        try Data([1, 2, 3])
            .write(to: root.appendingPathComponent("model.safetensors"))

        let first = makeModel(id: "profile-a", localName: root.path)
        let second = makeModel(id: "profile-b", localName: root.path)
        let external = makeModel(id: "owner/external", localName: "external")
        let service = RegisteredModelHealthService()

        let reports = await service.assess(models: [first, second, external])

        XCTAssertEqual(reports.first(where: { $0.id == first.id })?.status, .duplicatePath)
        XCTAssertEqual(reports.first(where: { $0.id == second.id })?.status, .duplicatePath)
        XCTAssertEqual(reports.first(where: { $0.id == external.id })?.status, .externalIdentifier)
    }

    func testRegisteredModelHealthReportsIncompleteModel() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try Data(#"{"model_type":"test"}"#.utf8)
            .write(to: root.appendingPathComponent("config.json"))
        let service = RegisteredModelHealthService()

        let reports = await service.assess(models: [makeModel(id: root.path, localName: root.path)])

        XCTAssertEqual(reports.first?.status, .incomplete)
        XCTAssertEqual(reports.first?.issue, .missingTokenizer)
    }

    func testResourceForecastRecommendsMemorySaverWithoutAutomaticPersistence() {
        let assessment = MultiModelMemoryAssessment(
            level: .critical,
            runningModelCount: 1,
            currentManagedMemoryGigabytes: 20,
            candidateFootprintGigabytes: 30,
            projectedManagedMemoryGigabytes: 50,
            projectedAvailableMemoryGigabytes: 1,
            reservedSystemMemoryGigabytes: 9.6
        )
        let recommendation = KVCacheRecommendation(
            entryLimit: 1,
            byteLimit: 1_073_741_824,
            projectedHeadroomGigabytes: 8
        )
        let safeMode = KVCacheSafeModeResult(
            advancedLaunchOptions: AdvancedLaunchOptions(promptCacheSize: "1"),
            recommendation: recommendation,
            adjustedEntryLimit: true,
            adjustedByteLimit: false
        )

        let forecast = StartResourceForecastAdvisor.make(
            profileID: "owner/model",
            assessment: assessment,
            currentOptions: .empty,
            safeModeResult: safeMode
        )

        XCTAssertEqual(forecast.recommendedTemplate, .memorySaver)
        XCTAssertTrue(forecast.didAdjustOptions)
        XCTAssertEqual(forecast.suggestedOptions.promptCacheSize, "1")
    }

    func testBenchmarkTuningRequiresCurrentMultiSampleEvidence() {
        let sample = makeSuccessfulBenchmark(score: 8, memory: 8, speed: 12)
        let session = BenchmarkSessionResult(
            profileID: "owner/model",
            modelID: "owner/model",
            selectedProfileName: "Model",
            preset: .standard,
            executionFingerprint: "fingerprint",
            samples: [sample, sample]
        )
        let currentRow = BenchmarkComparisonRow(
            profileID: "owner/model",
            displayName: "Model",
            session: session,
            exclusionReasons: [],
            recommendedUseCases: [.coding]
        )
        let staleRow = BenchmarkComparisonRow(
            profileID: "owner/model",
            displayName: "Model",
            session: session,
            exclusionReasons: [.executionConfigurationChanged],
            recommendedUseCases: []
        )

        XCTAssertEqual(
            BenchmarkProfileTuningAdvisor.recommendation(row: currentRow, useCase: .coding)?.template,
            .throughput
        )
        XCTAssertNil(BenchmarkProfileTuningAdvisor.recommendation(row: staleRow, useCase: .coding))
    }

    func testOperationalReadinessBlocksKnownRuntimeAndModelProblems() {
        let model = makeModel(id: "owner/model", localName: "/missing/model")
        let compatibility = ProfileCompatibilityAssessment(
            backend: .mlxLM,
            level: .blocked,
            requestedFlags: ["--temp"],
            unsupportedFlags: ["--temp"],
            checkedAt: Date()
        )
        let health = RegisteredModelHealthReport(
            profileID: model.id,
            displayName: model.displayName,
            modelID: model.modelID,
            status: .missing,
            localPath: "/missing/model",
            issue: nil,
            message: nil,
            sizeGigabytes: nil,
            modificationDate: nil,
            duplicateProfileIDs: [],
            checkedAt: Date()
        )
        let runtime = RuntimeReadinessReport(
            backend: .mlxLM,
            executablePath: "",
            issue: .pathNotConfigured,
            checkedAt: Date()
        )

        let report = OperationalReadinessProjector.makeReport(
            selectedModel: model,
            runtimeReadiness: runtime,
            compatibility: compatibility,
            healthReports: [health],
            portCheckResult: .available(host: "127.0.0.1", port: 8080),
            selectedEndpointIsActive: false,
            resourceForecast: nil,
            sessionRecoveryCandidateCount: 0,
            tuningRecommendations: [],
            hermesConfigPath: "",
            launchFailureDiagnosis: nil
        )

        XCTAssertEqual(report.overallStatus, .blocking)
        XCTAssertGreaterThanOrEqual(report.blockingCount, 3)
        XCTAssertTrue(report.copyText(language: .japanese).contains("起動不可"))
    }

    private func makeModel(id: String, localName: String) -> ModelConfig {
        ModelConfig(
            modelID: id,
            displayName: id,
            family: "Test",
            quantization: "4-bit",
            localName: localName,
            host: "127.0.0.1",
            serverPort: 8080,
            enableThinking: false,
            notes: "",
            advancedLaunchOptions: nil,
            backend: .mlxLM
        )
    }

    private func makeSuccessfulBenchmark(
        score: Int,
        memory: Double,
        speed: Double
    ) -> BenchmarkResult {
        BenchmarkResult(
            profileID: "owner/model",
            modelID: "owner/model",
            baseURL: "http://127.0.0.1:8080/v1",
            phase: .success,
            readinessLatencyMS: 20,
            selectedProfileName: "Model",
            message: "ok",
            speedMetrics: BenchmarkSpeedMetrics(
                readinessLatencyMS: 20,
                ttftMS: 100,
                totalLatencyMS: 1_000,
                outputTokensPerSecond: speed,
                outputTokenCount: 20,
                finishReason: "stop",
                httpStatusCode: 200,
                timedOut: false,
                errorMessage: nil,
                managedMemoryGigabytes: memory,
                availableMemoryGigabytes: 20
            ),
            useCaseScores: [
                BenchmarkUseCaseScore(
                    useCase: .coding,
                    score: score,
                    reasonCodes: [.generationStrong, .ttftResponsive]
                )
            ]
        )
    }
}
