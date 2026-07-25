import SwiftUI
import XCTest
@testable import MLXServerManager

@MainActor
final class MainSurfaceRenderingTests: XCTestCase {
    private struct Scenario {
        let name: String
        let language: AppLanguage
        let colorScheme: ColorScheme
        let size: CGSize
    }

    func testIntegratedWorkspaceRendersAcrossLanguageAppearanceAndWidth() throws {
        let scenarios = [
            Scenario(
                name: "english-light-wide",
                language: .english,
                colorScheme: .light,
                size: CGSize(width: 1_440, height: 900)
            ),
            Scenario(
                name: "japanese-dark-wide",
                language: .japanese,
                colorScheme: .dark,
                size: CGSize(width: 1_440, height: 900)
            ),
            Scenario(
                name: "english-dark-narrow",
                language: .english,
                colorScheme: .dark,
                size: CGSize(width: 980, height: 760)
            ),
            Scenario(
                name: "japanese-light-narrow",
                language: .japanese,
                colorScheme: .light,
                size: CGSize(width: 980, height: 760)
            )
        ]

        for scenario in scenarios {
            let context = try makeViewModel(language: scenario.language)
            defer { context.cleanup() }

            if let model = context.viewModel.selectedModel {
                context.viewModel.setRuntimeState(
                    .starting(host: model.host, port: model.serverPort),
                    for: model.id
                )
            }

            let view = ContentView(viewModel: context.viewModel)
                .environment(\.colorScheme, scenario.colorScheme)
                .frame(width: scenario.size.width, height: scenario.size.height)

            assertRenders(
                view,
                size: scenario.size,
                scenarioName: scenario.name
            )
        }
    }

    func testSecondarySurfacesRenderInBothLanguagesAndAppearances() throws {
        let scenarios = [
            Scenario(
                name: "english-light",
                language: .english,
                colorScheme: .light,
                size: CGSize(width: 1_000, height: 760)
            ),
            Scenario(
                name: "japanese-dark",
                language: .japanese,
                colorScheme: .dark,
                size: CGSize(width: 1_000, height: 760)
            )
        ]

        for scenario in scenarios {
            let context = try makeViewModel(language: scenario.language)
            defer { context.cleanup() }
            let recoveryRecord = SessionRecoveryRecord(
                sessionID: UUID(),
                disposition: .active,
                endpoints: [
                    SessionRecoveryEndpoint(
                        profileID: context.viewModel.models[0].id,
                        displayName: context.viewModel.models[0].displayName,
                        modelID: context.viewModel.models[0].modelID,
                        host: context.viewModel.models[0].host,
                        port: context.viewModel.models[0].serverPort
                    )
                ]
            )
            var recoveryState = SessionRecoveryViewState.presenting(record: recoveryRecord)
            recoveryState.complete([recoveryRecord.endpoints[0].id: .available(statusCode: 200)])
            let readinessReport = OperationalReadinessProjector.makeReport(
                selectedModel: context.viewModel.models[0],
                runtimeReadiness: RuntimeReadinessReport(
                    backend: context.viewModel.models[0].resolvedBackend,
                    executablePath: "/usr/local/bin/runtime",
                    issue: .ready(supportedFlagCount: 8),
                    checkedAt: Date()
                ),
                compatibility: ProfileCompatibilityAssessment(
                    backend: context.viewModel.models[0].resolvedBackend,
                    level: .compatible,
                    requestedFlags: [],
                    unsupportedFlags: [],
                    checkedAt: Date()
                ),
                healthReports: [],
                portCheckResult: .available(
                    host: context.viewModel.models[0].host,
                    port: context.viewModel.models[0].serverPort
                ),
                selectedEndpointIsActive: false,
                resourceForecast: nil,
                sessionRecoveryCandidateCount: 0,
                tuningRecommendations: [],
                hermesConfigPath: "~/.hermes/config.yaml",
                launchFailureDiagnosis: nil
            )
            var readinessState = OperationalReadinessViewState.hidden
            readinessState.complete(readinessReport)

            let surfaces: [(String, AnyView)] = [
                (
                    "downloads",
                    AnyView(
                        DownloadsSurfaceView(viewModel: context.viewModel)
                            .environment(\.colorScheme, scenario.colorScheme)
                    )
                ),
                (
                    "settings",
                    AnyView(
                        SettingsSurfaceView(viewModel: context.viewModel)
                            .environment(\.colorScheme, scenario.colorScheme)
                    )
                ),
                (
                    "logs-route",
                    AnyView(
                        IntegratedWorkspaceView(
                            viewModel: context.viewModel,
                            selectedDestination: .logs
                        )
                        .environment(\.colorScheme, scenario.colorScheme)
                    )
                ),
                (
                    "session-recovery",
                    AnyView(
                        SessionRecoveryView(
                            state: recoveryState,
                            models: context.viewModel.models,
                            language: scenario.language,
                            onCheck: {},
                            onAdopt: { _ in },
                            onDismiss: {}
                        )
                        .environment(\.colorScheme, scenario.colorScheme)
                    )
                ),
                (
                    "operational-readiness",
                    AnyView(
                        OperationalReadinessView(
                            state: readinessState,
                            language: scenario.language,
                            onRefresh: {},
                            onCancel: {},
                            onCopy: {},
                            onReviewUnsupportedOptions: {},
                            onReviewResourceForecast: {},
                            onReviewTuning: { _ in },
                            onDismiss: {}
                        )
                        .environment(\.colorScheme, scenario.colorScheme)
                    )
                )
            ]

            for surface in surfaces {
                assertRenders(
                    surface.1.frame(width: scenario.size.width, height: scenario.size.height),
                    size: scenario.size,
                    scenarioName: "\(scenario.name)-\(surface.0)"
                )
            }
        }
    }

    private func makeViewModel(language: AppLanguage) throws -> RenderingContext {
        let directoryName = "MLXServerManagerRenderingTests-\(UUID().uuidString)"
        let store = SettingsStore(appDirectoryName: directoryName)
        let viewModel = AppViewModel(settingsStore: store)
        viewModel.settings.uiLanguage = language
        viewModel.settings.uiAppearance = language == .japanese ? "dark" : "light"
        return RenderingContext(viewModel: viewModel, directoryURL: try store.settingsDirectoryURL)
    }

    private func assertRenders<Content: View>(
        _ content: Content,
        size: CGSize,
        scenarioName: String
    ) {
        let renderer = ImageRenderer(content: content)
        renderer.proposedSize = ProposedViewSize(width: size.width, height: size.height)
        renderer.scale = 1

        guard let image = renderer.cgImage else {
            XCTFail("Could not render \(scenarioName).")
            return
        }

        XCTAssertGreaterThan(image.width, 0, scenarioName)
        XCTAssertGreaterThan(image.height, 0, scenarioName)
        XCTAssertLessThanOrEqual(abs(image.width - Int(size.width)), 1, scenarioName)
        XCTAssertLessThanOrEqual(abs(image.height - Int(size.height)), 1, scenarioName)
    }
}

@MainActor
private struct RenderingContext {
    let viewModel: AppViewModel
    let directoryURL: URL

    func cleanup() {
        try? FileManager.default.removeItem(at: directoryURL)
    }
}
