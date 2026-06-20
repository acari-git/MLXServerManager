import XCTest
@testable import MLXServerManager

@MainActor
final class AppSectionTests: XCTestCase {
    func testV6TwoSectionsAreStable() {
        XCTAssertEqual(AppSection.allCases, [.dashboard, .profiles, .inspector])
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
}
