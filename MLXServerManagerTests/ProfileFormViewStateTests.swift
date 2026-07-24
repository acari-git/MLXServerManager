import XCTest
@testable import MLXServerManager

final class ProfileFormViewStateTests: XCTestCase {
    func testPresentPublishesDraftVisibilityAndMessagesTogether() {
        var state = ProfileFormViewState.hidden
        let draft = ModelProfileDraft.newProfile(defaultHost: "127.0.0.1", defaultPort: 8000)

        state.present(
            draft: draft,
            message: "Validation failed",
            portSuggestionMessage: "Port 8001 is available."
        )

        XCTAssertEqual(state.draft, draft)
        XCTAssertTrue(state.isPresented)
        XCTAssertEqual(state.message, "Validation failed")
        XCTAssertEqual(state.portSuggestionMessage, "Port 8001 is available.")
    }

    func testApplyPortSuggestionUpdatesDraftAndMessageTogether() {
        var state = ProfileFormViewState.hidden
        state.present(draft: .newProfile(defaultHost: "localhost", defaultPort: 8000))

        state.applyPortSuggestion(
            portText: "8002",
            message: "Port 8002 is available."
        )

        XCTAssertEqual(state.draft.serverPortText, "8002")
        XCTAssertEqual(state.portSuggestionMessage, "Port 8002 is available.")
        XCTAssertTrue(state.isPresented)
    }

    func testDraftAndValidationMessageUpdatesPreserveOtherFormState() {
        var state = ProfileFormViewState.hidden
        var draft = ModelProfileDraft.newProfile(defaultHost: "localhost", defaultPort: 8000)
        state.present(
            draft: draft,
            portSuggestionMessage: "Port 8000 is available."
        )

        draft.displayName = "Updated"
        state.setDraft(draft)
        state.setMessage("Invalid model ID")

        XCTAssertEqual(state.draft.displayName, "Updated")
        XCTAssertEqual(state.message, "Invalid model ID")
        XCTAssertEqual(state.portSuggestionMessage, "Port 8000 is available.")
        XCTAssertTrue(state.isPresented)
    }

    func testDismissClearsAllTransientFormState() {
        var state = ProfileFormViewState.hidden
        state.present(
            draft: .newProfile(defaultHost: "localhost", defaultPort: 8000),
            message: "message",
            portSuggestionMessage: "suggestion"
        )

        state.dismiss()

        XCTAssertEqual(state, .hidden)
    }
}
