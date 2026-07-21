import XCTest
@testable import MLXServerManager

final class NetworkExposureAdvisorTests: XCTestCase {
    func testLoopbackHostsRemainLocalOnly() {
        let hosts = [
            "127.0.0.1",
            "127.255.10.2",
            "localhost",
            "LOCALHOST.",
            "api.localhost",
            "::1",
            "[::1]"
        ]

        for host in hosts {
            XCTAssertEqual(
                NetworkExposureAdvisor.assess(host: host),
                .localOnly,
                "Expected \(host) to remain local-only"
            )
        }
    }

    func testNonLoopbackHostsRequireExplicitConfirmation() {
        let expected: [(String, NetworkExposureAssessment)] = [
            ("0.0.0.0", .networkAccessible(host: "0.0.0.0")),
            ("::", .networkAccessible(host: "::")),
            ("192.168.1.20", .networkAccessible(host: "192.168.1.20")),
            ("mlx-server.local", .networkAccessible(host: "mlx-server.local"))
        ]

        for (host, assessment) in expected {
            XCTAssertEqual(NetworkExposureAdvisor.assess(host: host), assessment)
            XCTAssertTrue(assessment.requiresExplicitStartConfirmation)
        }
    }

    func testSafetyAndConfirmationTextAreLocalized() {
        let assessment = NetworkExposureAdvisor.assess(host: "0.0.0.0")

        XCTAssertTrue(assessment.safetyText(language: .english).contains("Warning"))
        XCTAssertTrue(assessment.safetyText(language: .japanese).contains("警告"))
        XCTAssertTrue(assessment.confirmationDetail(language: .english).contains("0.0.0.0"))
        XCTAssertTrue(assessment.confirmationDetail(language: .japanese).contains("0.0.0.0"))
    }
}

@MainActor
final class NetworkExposureStartConfirmationTests: XCTestCase {
    func testStartRequestForNetworkAccessibleHostRequiresConfirmationBeforeLaunch() {
        let viewModel = AppViewModel()
        let model = ModelConfig(
            modelID: "owner/network-model",
            displayName: "Network Model",
            family: "Test",
            quantization: "4-bit",
            localName: "network-model",
            host: "0.0.0.0",
            serverPort: 8_000,
            enableThinking: false,
            notes: "",
            advancedLaunchOptions: nil
        )

        viewModel.models = [model]
        viewModel.startRequested(for: model)

        XCTAssertTrue(viewModel.isNetworkExposureStartConfirmationPresented)
        XCTAssertEqual(
            viewModel.pendingNetworkExposureAssessment,
            .networkAccessible(host: "0.0.0.0")
        )

        viewModel.cancelNetworkExposureStart()
        XCTAssertFalse(viewModel.isNetworkExposureStartConfirmationPresented)
        XCTAssertNil(viewModel.pendingNetworkExposureAssessment)
    }
}
