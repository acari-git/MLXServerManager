import XCTest
@testable import MLXServerManager

final class AppSettingsTests: XCTestCase {
    func testDefaultsIncludeSavedChromePreferences() {
        let settings = AppSettings.defaults

        XCTAssertEqual(settings.uiLanguage, .system)
        XCTAssertEqual(settings.uiAccentColor, "blue")
        XCTAssertEqual(settings.uiAppearance, "system")
    }

    func testDecodingLegacySettingsFillsChromePreferences() throws {
        let json = """
        {
          "mlxServerExecutablePath": "",
          "defaultHost": "127.0.0.1",
          "defaultPort": 8080,
          "apiKeyPlaceholder": "not-required-local"
        }
        """.data(using: .utf8)!

        let settings = try JSONDecoder().decode(AppSettings.self, from: json)

        XCTAssertEqual(settings.uiLanguage, .system)
        XCTAssertEqual(settings.uiAccentColor, "blue")
        XCTAssertEqual(settings.uiAppearance, "system")
    }

    func testEncodingRoundTripsChromePreferences() throws {
        let original = AppSettings(
            mlxServerExecutablePath: "/tmp/mlx_lm.server",
            defaultHost: "127.0.0.1",
            defaultPort: 9999,
            apiKeyPlaceholder: "local-only",
            uiLanguage: .english,
            uiAccentColor: "purple",
            uiAppearance: "dark"
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AppSettings.self, from: data)

        XCTAssertEqual(decoded.uiLanguage, .english)
        XCTAssertEqual(decoded.uiAccentColor, "purple")
        XCTAssertEqual(decoded.uiAppearance, "dark")
    }
}
