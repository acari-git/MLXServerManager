import XCTest
@testable import MLXServerManager

@MainActor
final class AppSectionTests: XCTestCase {
    func testDashboardIsOnlyV6ZeroSection() {
        XCTAssertEqual(AppSection.allCases, [.dashboard])
    }

    func testDashboardMetadataIsStable() {
        let section = AppSection.dashboard

        XCTAssertEqual(section.id, "dashboard")
        XCTAssertEqual(section.title, "Dashboard")
        XCTAssertEqual(section.subtitle, "Current Direct Mode control surface")
        XCTAssertEqual(section.systemImageName, "rectangle.grid.2x2")
        XCTAssertEqual(section.accessibilityIdentifier, "app-section-dashboard")
    }
}
