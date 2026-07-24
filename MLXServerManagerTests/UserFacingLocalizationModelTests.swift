import XCTest
@testable import MLXServerManager

final class UserFacingLocalizationModelTests: XCTestCase {
    func testRuntimeStateLocalizesTitlesBadgesAndMenuStatus() {
        let ready = ModelRuntimeState.ready(
            host: "127.0.0.1",
            port: 8080,
            processIdentifier: 123
        )
        let degraded = ModelRuntimeState.degraded(
            host: "127.0.0.1",
            port: 8080,
            processIdentifier: 123,
            message: "fault"
        )

        XCTAssertEqual(ready.localizedTitle(language: .japanese), "準備完了")
        XCTAssertEqual(ready.localizedMenuBarStatus(language: .japanese), "準備完了")
        XCTAssertEqual(ready.localizedBadgeDetail(language: .japanese), "127.0.0.1:8080, pid 123")
        XCTAssertEqual(degraded.localizedTitle(language: .japanese), "異常")
        XCTAssertTrue(degraded.localizedBadgeDetail(language: .japanese).contains("異常"))
        XCTAssertEqual(degraded.localizedMenuBarStatus(language: .japanese), "失敗")
        XCTAssertEqual(ready.localizedTitle(language: .english), "Ready")
    }

    func testImportValidationLocalizesStatusAndKnownMessages() {
        let exact = ImportValidationMessage(
            severity: .error,
            message: "Profile name is required."
        )
        let dynamic = ImportValidationMessage(
            severity: .warning,
            message: "Profile #2 contains secret-looking field(s). They are ignored by preview and will not be imported."
        )

        XCTAssertEqual(exact.localizedMessage(language: .japanese), "プロファイル名が必要です。")
        XCTAssertTrue(dynamic.localizedMessage(language: .japanese).contains("インポートされません"))
        XCTAssertEqual(ImportProfileValidationStatus.valid.localizedTitle(language: .japanese), "有効")
        XCTAssertEqual(ImportProfileValidationStatus.invalid.localizedTitle(language: .english), "Invalid")
    }

    func testRecoveryIssueAndActionLocalizeUserFacingText() {
        let action = RecoveryAction(
            kind: .runDiagnostics,
            title: "Run Diagnostics",
            detail: "Check setup readiness.",
            isPrimary: true
        )
        let issue = RecoveryIssue(
            category: .executableMissing,
            severity: .failed,
            title: "Executable Missing",
            detail: "Set the executable path.",
            relatedLogLine: nil,
            actions: [action]
        )

        XCTAssertEqual(issue.severity.localizedTitle(language: .japanese), "失敗")
        XCTAssertEqual(issue.localizedTitle(language: .japanese), "実行ファイルがありません")
        XCTAssertTrue(issue.localizedDetail(language: .japanese).contains("実行ファイルパス"))
        XCTAssertEqual(action.localizedTitle(language: .japanese), "診断を実行")
        XCTAssertTrue(action.localizedDetail(language: .japanese).contains("セットアップ"))
    }

    func testDownloadPreviewLocalizesValidationMessages() {
        var draft = HuggingFaceDownloadDraft.defaults(defaultHost: "127.0.0.1", defaultPort: 8080)
        let emptyPreview = HuggingFaceDownloadPreview.make(draft: draft)
        XCTAssertEqual(
            emptyPreview.localizedMessage(language: .japanese),
            "Hugging FaceのModel IDまたはモデルURLを入力してください。"
        )

        draft.source = "invalid"
        let invalidPreview = HuggingFaceDownloadPreview.make(draft: draft)
        XCTAssertTrue(invalidPreview.localizedMessage(language: .japanese).contains("owner/model-name"))
        XCTAssertFalse(invalidPreview.localizedMessage(language: .japanese).contains("Use a model ID"))
    }

    func testDownloadQueueProgressLocalizesUnits() {
        let entry = HuggingFaceDownloadQueueEntry(
            id: UUID(),
            repositoryID: "owner/model",
            destinationPath: "/tmp/model",
            phase: .downloading,
            message: "Downloading",
            fileCount: 10,
            downloadedFileCount: 3,
            downloadedBytes: 400,
            totalBytes: 1_000,
            speedBytesPerSecond: 200
        )

        XCTAssertTrue(entry.localizedProgressText(language: .japanese).contains("ファイル"))
        XCTAssertFalse(entry.localizedProgressText(language: .japanese).contains("files"))
        XCTAssertTrue(entry.localizedProgressText(language: .english).contains("files"))
    }
}
