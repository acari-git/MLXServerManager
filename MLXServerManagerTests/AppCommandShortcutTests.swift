import Foundation
import XCTest
@testable import MLXServerManager

@MainActor
final class AppCommandShortcutTests: XCTestCase {
    // MARK: - Shortcut definition

    func testOpenSettingsUsesStandardCommandCommaBinding() {
        let shortcut = AppCommandShortcut.openSettings

        XCTAssertEqual(shortcut.key.character, ",")
        XCTAssertEqual(shortcut.modifiers, .command)
        XCTAssertEqual(shortcut.displayText, "⌘,")
    }

    func testOpenSettingsTargetsSettingsDestination() {
        XCTAssertEqual(AppCommandShortcut.openSettings.destination, .settings)
    }

    func testOpenSettingsTitleIsLocalizedWithEllipsis() {
        XCTAssertEqual(AppCommandShortcut.openSettings.title(language: .english), "Settings…")
        XCTAssertEqual(AppCommandShortcut.openSettings.title(language: .japanese), "設定…")
    }

    func testOpenSettingsTitleMatchesSettingsDestinationTitle() {
        for language in [AppLanguage.english, AppLanguage.japanese] {
            let destinationTitle = IntegratedWorkspaceDestination.settings.title(language: language)
            XCTAssertEqual(
                AppCommandShortcut.openSettings.title(language: language),
                destinationTitle + "…"
            )
        }
    }

    func testShortcutBindingsAreUnique() {
        let bindings = AppCommandShortcut.allCases.map {
            "\($0.modifiers.rawValue)-\($0.key.character)"
        }

        XCTAssertEqual(Set(bindings).count, bindings.count)
    }

    // MARK: - Navigation request

    func testOpenSettingsRequestedPublishesSettingsDestination() {
        let viewModel = makeViewModel()

        XCTAssertNil(viewModel.pendingWorkspaceDestination)

        viewModel.openSettingsRequested()

        XCTAssertEqual(viewModel.pendingWorkspaceDestination, .settings)
    }

    func testConsumePendingWorkspaceDestinationReturnsRequestAndClearsIt() {
        let viewModel = makeViewModel()
        viewModel.openSettingsRequested()

        XCTAssertEqual(viewModel.consumePendingWorkspaceDestination(), .settings)
        XCTAssertNil(viewModel.pendingWorkspaceDestination)
        XCTAssertNil(viewModel.consumePendingWorkspaceDestination())
    }

    func testConsumeWithoutRequestReturnsNil() {
        let viewModel = makeViewModel()

        XCTAssertNil(viewModel.consumePendingWorkspaceDestination())
    }

    func testLatestWorkspaceDestinationRequestWins() {
        let viewModel = makeViewModel()

        viewModel.requestWorkspaceDestination(.logs)
        viewModel.openSettingsRequested()

        XCTAssertEqual(viewModel.consumePendingWorkspaceDestination(), .settings)
    }

    func testOpeningSettingsDoesNotChangeSavedSettings() {
        let viewModel = makeViewModel()
        let before = viewModel.settings

        viewModel.openSettingsRequested()
        _ = viewModel.consumePendingWorkspaceDestination()

        XCTAssertEqual(viewModel.settings, before)
    }

    // MARK: - Wiring guards

    func testAppRegistersCommandsAndReplacesSettingsMenuSlot() throws {
        let root = try Self.projectRoot()
        let app = try String(
            contentsOf: root.appendingPathComponent("MLXServerManager/MLXServerManagerApp.swift"),
            encoding: .utf8
        )
        let commands = try String(
            contentsOf: root.appendingPathComponent("MLXServerManager/Views/AppCommands.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(app.contains(".commands"))
        XCTAssertTrue(app.contains("AppCommands(viewModel: viewModel)"))
        XCTAssertTrue(commands.contains("CommandGroup(replacing: .appSettings)"))
        XCTAssertTrue(commands.contains(".keyboardShortcut("))
    }

    func testWorkspaceViewConsumesPendingDestination() throws {
        let root = try Self.projectRoot()
        let workspace = try String(
            contentsOf: root.appendingPathComponent("MLXServerManager/Views/IntegratedWorkspaceView.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(workspace.contains("consumePendingWorkspaceDestination()"))
        XCTAssertTrue(workspace.contains("onChange(of: viewModel.pendingWorkspaceDestination)"))
    }

    // MARK: - Helpers

    private func makeViewModel() -> AppViewModel {
        AppViewModel(
            settingsStore: SettingsStore(
                appDirectoryName: "MLXServerManagerTests-\(UUID().uuidString)"
            )
        )
    }

    private static func projectRoot() throws -> URL {
        var directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        while directory.path != "/" {
            if FileManager.default.fileExists(
                atPath: directory.appendingPathComponent("MLXServerManager.xcodeproj").path
            ) {
                return directory
            }
            directory.deleteLastPathComponent()
        }
        throw NSError(domain: "AppCommandShortcutTests", code: 1)
    }
}
