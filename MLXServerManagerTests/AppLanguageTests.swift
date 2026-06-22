import XCTest
@testable import MLXServerManager

final class AppLanguageTests: XCTestCase {
    func testEnglishLocalizationUsesExpectedPrimaryLabels() {
        let strings = AppLocalization(language: .english)

        XCTAssertEqual(strings.text(.dashboard), "Dashboard")
        XCTAssertEqual(strings.text(.models), "Models")
        XCTAssertEqual(strings.text(.downloads), "Downloads")
        XCTAssertEqual(strings.text(.runtime), "Runtime")
        XCTAssertEqual(strings.text(.settings), "Settings")
        XCTAssertEqual(strings.text(.logs), "Logs")
    }

    func testJapaneseLocalizationUsesExpectedPrimaryLabels() {
        let strings = AppLocalization(language: .japanese)

        XCTAssertEqual(strings.text(.dashboard), "ダッシュボード")
        XCTAssertEqual(strings.text(.models), "モデル")
        XCTAssertEqual(strings.text(.downloads), "ダウンロード")
        XCTAssertEqual(strings.text(.runtime), "ランタイム")
        XCTAssertEqual(strings.text(.settings), "設定")
        XCTAssertEqual(strings.text(.logs), "ログ")
    }
}
