import XCTest
@testable import MLXServerManager

final class HuggingFaceFilePreviewViewStateTests: XCTestCase {
    private let firstFile = HuggingFaceDownloadPreviewFile(
        path: "model-00001-of-00002.safetensors",
        size: 100
    )
    private let secondFile = HuggingFaceDownloadPreviewFile(
        path: "config.json",
        size: 20
    )

    func testBeginProjectsIdentityLoadingStateAndClearsPreviousSelection() {
        var state = HuggingFaceFilePreviewViewState.waiting
        state.begin(
            identity: HuggingFaceFilePreviewIdentity(
                repositoryID: " owner/model ",
                revision: " "
            ),
            message: "Fetching"
        )

        XCTAssertEqual(
            state.identity,
            HuggingFaceFilePreviewIdentity(repositoryID: "owner/model", revision: "main")
        )
        XCTAssertTrue(state.preview.isLoading)
        XCTAssertEqual(state.preview.message, "Fetching")
        XCTAssertTrue(state.preview.files.isEmpty)
        XCTAssertTrue(state.selectedFileIDs.isEmpty)
    }

    func testCompletePublishesFilesMessageAndDefaultSelectionTogether() {
        let identity = HuggingFaceFilePreviewIdentity(repositoryID: "owner/model", revision: "dev")
        var state = HuggingFaceFilePreviewViewState.waiting
        state.begin(identity: identity, message: "Fetching")

        state.complete(files: [firstFile, secondFile], message: "Ready")

        XCTAssertEqual(state.identity, identity)
        XCTAssertFalse(state.preview.isLoading)
        XCTAssertEqual(state.preview.message, "Ready")
        XCTAssertEqual(state.preview.files, [firstFile, secondFile])
        XCTAssertEqual(state.selectedFileIDs, [firstFile.id, secondFile.id])
    }

    func testSelectionOperationsPreservePreviewAndIdentity() {
        let identity = HuggingFaceFilePreviewIdentity(repositoryID: "owner/model", revision: "main")
        var state = HuggingFaceFilePreviewViewState.waiting
        state.begin(identity: identity, message: "Fetching")
        state.complete(files: [firstFile, secondFile], message: "Ready")

        state.toggle(fileID: firstFile.id)
        XCTAssertEqual(state.selectedFileIDs, [secondFile.id])

        state.clearSelection()
        XCTAssertTrue(state.selectedFileIDs.isEmpty)

        state.select(fileIDs: [firstFile.id])
        XCTAssertEqual(state.selectedFileIDs, [firstFile.id])
        XCTAssertEqual(state.identity, identity)
        XCTAssertEqual(state.preview.files, [firstFile, secondFile])
    }

    func testFailureRejectionAndResetClearUnsafeSelectionState() {
        let identity = HuggingFaceFilePreviewIdentity(repositoryID: "owner/model", revision: "main")
        var state = HuggingFaceFilePreviewViewState.waiting
        state.begin(identity: identity, message: "Fetching")
        state.complete(files: [firstFile], message: "Ready")

        state.fail(message: "Network failed")
        XCTAssertEqual(state.identity, identity)
        XCTAssertFalse(state.preview.isLoading)
        XCTAssertEqual(state.preview.message, "Network failed")
        XCTAssertTrue(state.preview.files.isEmpty)
        XCTAssertTrue(state.selectedFileIDs.isEmpty)

        state.reject(message: "Invalid model")
        XCTAssertNil(state.identity)
        XCTAssertEqual(state.preview.message, "Invalid model")

        state.reset()
        XCTAssertEqual(state, .waiting)
    }
}
