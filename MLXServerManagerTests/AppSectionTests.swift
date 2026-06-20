import XCTest
@testable import MLXServerManager

@MainActor
final class AppSectionTests: XCTestCase {
    func testV6FiveSectionsAreStable() {
        XCTAssertEqual(AppSection.allCases, [.dashboard, .profiles, .inspector, .logs, .clientSetup, .metrics])
    }

    func testDashboardMetadataIsStable() {
        let section = AppSection.dashboard

        XCTAssertEqual(section.id, "dashboard")
        XCTAssertEqual(section.title, "Dashboard")
        XCTAssertEqual(section.subtitle, "Current Direct Mode control surface")
        XCTAssertEqual(section.systemImageName, "rectangle.grid.2x2")
        XCTAssertEqual(section.accessibilityIdentifier, "app-section-dashboard")
    }

    func testProfilesMetadataIsStable() {
        let section = AppSection.profiles

        XCTAssertEqual(section.id, "profiles")
        XCTAssertEqual(section.title, "Profiles")
        XCTAssertEqual(section.subtitle, "Model profile list surface")
        XCTAssertEqual(section.systemImageName, "list.bullet.rectangle")
        XCTAssertEqual(section.accessibilityIdentifier, "app-section-profiles")
    }

    func testInspectorMetadataIsStable() {
        let section = AppSection.inspector

        XCTAssertEqual(section.id, "inspector")
        XCTAssertEqual(section.title, "Inspector")
        XCTAssertEqual(section.subtitle, "Selected profile detail surface")
        XCTAssertEqual(section.systemImageName, "sidebar.right")
        XCTAssertEqual(section.accessibilityIdentifier, "app-section-inspector")
    }

    func testLogsMetadataIsStable() {
        let section = AppSection.logs

        XCTAssertEqual(section.id, "logs")
        XCTAssertEqual(section.title, "Logs")
        XCTAssertEqual(section.subtitle, "Managed log context surface")
        XCTAssertEqual(section.systemImageName, "doc.text.magnifyingglass")
        XCTAssertEqual(section.accessibilityIdentifier, "app-section-logs")
    }

    func testClientSetupMetadataIsStable() {
        let section = AppSection.clientSetup

        XCTAssertEqual(section.id, "clientSetup")
        XCTAssertEqual(section.title, "Client Setup")
        XCTAssertEqual(section.subtitle, "OpenAI-compatible setup values")
        XCTAssertEqual(section.systemImageName, "link.badge.plus")
        XCTAssertEqual(section.accessibilityIdentifier, "app-section-clientSetup")
    }

    func testMetricsMetadataIsStable() {
        let section = AppSection.metrics

        XCTAssertEqual(section.id, "metrics")
        XCTAssertEqual(section.title, "Metrics")
        XCTAssertEqual(section.subtitle, "Read-only system context")
        XCTAssertEqual(section.systemImageName, "gauge.with.dots.needle.67percent")
        XCTAssertEqual(section.accessibilityIdentifier, "app-section-metrics")
    }
}
