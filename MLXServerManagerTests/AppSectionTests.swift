import XCTest
@testable import MLXServerManager

@MainActor
final class AppSectionTests: XCTestCase {
    func testV6OneSectionsAreStable() {
        XCTAssertEqual(AppSection.allCases, [.dashboard, .profiles])
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
}
