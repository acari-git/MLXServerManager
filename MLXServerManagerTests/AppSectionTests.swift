import XCTest
@testable import MLXServerManager

@MainActor
final class AppSectionTests: XCTestCase {
    func testV14SixSectionsAreStable() {
        XCTAssertEqual(AppSection.allCases, [.dashboard, .profiles, .inspector, .logs, .clientSetup, .metrics])
        XCTAssertEqual(AppSection.v14NavigationOrder, [.dashboard, .profiles, .clientSetup, .inspector, .metrics, .logs])
    }

    func testLocalizedNavigationLabelsUseV14SurfaceNames() {
        XCTAssertEqual(AppSection.dashboard.localizedTitle(language: .english), "Dashboard")
        XCTAssertEqual(AppSection.profiles.localizedTitle(language: .english), "Models")
        XCTAssertEqual(AppSection.clientSetup.localizedTitle(language: .english), "Downloads")
        XCTAssertEqual(AppSection.inspector.localizedTitle(language: .english), "Runtime")
        XCTAssertEqual(AppSection.metrics.localizedTitle(language: .english), "Settings")
        XCTAssertEqual(AppSection.logs.localizedTitle(language: .english), "Logs")

        XCTAssertEqual(AppSection.dashboard.localizedTitle(language: .japanese), "ダッシュボード")
        XCTAssertEqual(AppSection.profiles.localizedTitle(language: .japanese), "モデル")
        XCTAssertEqual(AppSection.clientSetup.localizedTitle(language: .japanese), "ダウンロード")
        XCTAssertEqual(AppSection.inspector.localizedTitle(language: .japanese), "ランタイム")
        XCTAssertEqual(AppSection.metrics.localizedTitle(language: .japanese), "設定")
        XCTAssertEqual(AppSection.logs.localizedTitle(language: .japanese), "ログ")
    }

    func testAccessibilityIdentifiersRemainStable() {
        XCTAssertEqual(AppSection.dashboard.accessibilityIdentifier, "app-section-dashboard")
        XCTAssertEqual(AppSection.profiles.accessibilityIdentifier, "app-section-profiles")
        XCTAssertEqual(AppSection.inspector.accessibilityIdentifier, "app-section-inspector")
        XCTAssertEqual(AppSection.logs.accessibilityIdentifier, "app-section-logs")
        XCTAssertEqual(AppSection.clientSetup.accessibilityIdentifier, "app-section-clientSetup")
        XCTAssertEqual(AppSection.metrics.accessibilityIdentifier, "app-section-metrics")
    }
}
